package org.trisano.mondrian;

import mondrian.olap.*;
import mondrian.olap.type.*;
import mondrian.spi.UserDefinedFunction;
import org.apache.log4j.Logger;
import java.sql.*;
import java.util.*;
import java.lang.Exception;

public class GetPopulation implements UserDefinedFunction {
    private static final Logger logger = Logger.getLogger(GetPopulation.class);

    public GetPopulation() { }

    public String getName() { return "GetPopulation"; }

    public String getDescription() {
        return "Returns the population for the current context";
    }

    public Syntax getSyntax() { return Syntax.Function; }

    public Type getReturnType(Type[] parameterTypes) {
        return new NumericType();
    }

    public Type[] getParameterTypes() {
        return new Type[] { new NumericType() };
    }

    class GetPopulationException extends Exception {
        GetPopulationException() {
            super();
        }

        GetPopulationException(String s) {
            super(s);
        }
    }

    public Object execute(Evaluator evaluator, UserDefinedFunction.Argument[] arguments) {
        java.sql.Connection conn = null;
        List<Map<String, String>> dimensions = new ArrayList<Map<String, String>>();
        ResultSet rs;
        String column_names = new String("");
        String table_name, query;
        Integer table_rank, population = 0;
        ArrayList<String> params = new ArrayList<String>();
        Boolean doneOne = false;

        if (! (arguments[0].evaluateScalar(evaluator) instanceof Number)) {
            // In case there's no Count, also return null Population, so that the NON-EMPTY
            // row thing can remove this row
            logger.debug("GetPopulation called with null Count value");
            return null;
        }
        try {
            conn = evaluator.getQuery().getConnection().getDataSource().getConnection();
            PreparedStatement st =
                conn.prepareStatement("SELECT dim_cols[?], mapping_func[?], required FROM population.population_dimensions WHERE dim_name = ?");

            // Get data on all necessary dimensions
            for (Dimension d : evaluator.getCube().getDimensions()) {
                Integer depth;

                // XXX: This only supports dimensions with one hierarchy
                if (d.getHierarchies() == null || d.getHierarchies().length == 0)
                    continue;

                logger.debug("checking dimension " + d.getName());
                HashMap<String, String> dimhash = new HashMap<String, String>();
                depth = evaluator.getContext(d.getHierarchies()[0]).getLevel().getDepth();

                st.setInt(1, depth);
                st.setInt(2, depth);
                st.setString(3, d.getName());
                rs = st.executeQuery();
                if (rs.next()) {
                    if (depth != 0) {
                        // rs.next() is true only if it returned something, or in
                        // other words, only when this dimension is important to
                        // us. Nonzero depth means the user has selected a level of this
                        // dimension
                        dimhash.put("name", d.getName());
                        dimhash.put("depth", depth.toString());
                        dimhash.put("value", evaluator.getContext(d.getHierarchies()[0]).getName());
                        dimhash.put("column", rs.getString(1));
                        dimhash.put("mapper", rs.getString(2));
                        dimensions.add(dimhash);
                        if (! column_names.equals(""))
                            column_names += ", ";
                        column_names += "'" + dimhash.get("column") + "'";
                        logger.info("Dimension " + d.getName() + " is useful, so keeping. Column: " + dimhash.get("column") + "\tMapper: " + dimhash.get("mapper"));
                        logger.debug("column names list now == " + column_names);
                    }
                    else if (rs.getBoolean(3)) {
                        // If depth is zero but required is true, return nothing,
                        // because the user hasn't specified all required values to get a population
                        throw this.new GetPopulationException("Dimension " + d.getName() + " unspecified, but required for population data output");
                    }
                }
            }

            // Figure out what table to use
            // TODO: Note that there's some room for SQL injection problems here, if column names are stupid
            if (dimensions.size() != 0) {
                query =
                    "SELECT table_name, table_rank FROM (                \n" +
                    "    SELECT                                          \n" +
                    "        ppt.table_name,                             \n" +
                    "        COUNT(*),                                   \n" +
                    "        ppt.table_rank                              \n" +
                    "    FROM                                            \n" +
                    "        population.population_tables ppt            \n" +
                    "        JOIN information_schema.columns isc         \n" +
                    "            ON (                                    \n" +
                    "                isc.table_name = ppt.table_name AND \n" +
                    "                isc.table_schema = 'population'     \n" +
                    "            )                                       \n" +
                    "    WHERE                                           \n" +
                    "       isc.column_name IN (" + column_names + ")    \n" +
                    "    GROUP BY                                        \n" +
                    "        ppt.table_name,                             \n" +
                    "        ppt.table_rank                              \n" +
                    "    HAVING                                          \n" +
                    "        COUNT(*) = ?                                \n" +
                    ") f                                                 \n" +
                    "ORDER BY table_rank ASC LIMIT 1;";
                logger.debug("For finding table, using query : " + query);
                st = conn.prepareStatement(query);
                //st.setString(1, column_names);
                st.setInt(1, dimensions.size());
                rs = st.executeQuery();
                if (rs.next()) {
                    table_name = rs.getString(1);
                    table_rank = rs.getInt(2);
                }
                else
                    throw this.new GetPopulationException("Couldn't find population table for dimensions: " + column_names);
            }
            else {
                logger.debug("No dimensions specified; using highest-ranking table");
                st = conn.prepareStatement("SELECT table_name, table_rank FROM population.population_tables ORDER BY table_rank ASC LIMIT 1");
                rs = st.executeQuery();
                if (rs.next()) {
                    table_name = rs.getString(1);
                    table_rank = rs.getInt(2);
                }
                else
                    throw this.new GetPopulationException("Couldn't find default population table");

                if (table_name == null || table_name.equals(""))
                    throw this.new GetPopulationException("Found a default population table, but it has no name");
            }
            logger.info("Pulling data from table " + table_name + " with rank " + table_rank.toString());

            // Build query
            query = "SELECT COALESCE(SUM(population), 0) FROM population." + table_name;
            if (dimensions.size() > 0) {
                query += " WHERE";
                for (Map<String, String> m : dimensions) {
                    if (doneOne) 
                        query += " AND";
                    query += " " + m.get("column") + " = ";
                    if (m.get("mapper") == null) 
                        query += "?";
                    else
                        query += m.get("mapper") + "(?)";

                    params.add(m.get("value"));
                    doneOne = true;
                }
            }
            
            logger.info("Using query : " + query);
            st = conn.prepareStatement(query);
            int i = 1;
            for (String s : params) {
                st.setString(i, s);
                i++;
            }
            rs = st.executeQuery();
            rs.next();
            population = rs.getInt(1);
            logger.debug("Population: " + population);
        }
        catch (SQLException s) {
            logger.error("JDBC Error", s);
        }
        catch (GetPopulationException e) {
            logger.info("Problem getting population", e);
        }

        try {
            if (conn != null)
                conn.close();
        }
        catch (SQLException s) {
            logger.error("JDBC Error when disconnecting: ", s);
        }

        return population;
    }

    public String[] getReservedWords() { return null; }
}
