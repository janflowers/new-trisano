-- Copyright (C) 2007, 2008, 2009 The Collaborative Software Foundation
--
-- This file is part of TriSano.
--
-- TriSano is free software: you can redistribute it and/or modify it under the
-- terms of the GNU Affero General Public License as published by the
-- Free Software Foundation, either version 3 of the License,
-- or (at your option) any later version.
--
-- TriSano is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with TriSano. If not, see http://www.gnu.org/licenses/agpl-3.0.txt.

CREATE SCHEMA trisano;
ALTER SCHEMA trisano OWNER TO trisano_su;
CREATE LANGUAGE plpgsql;
-- NOTE: Adjust this user to the DEST_DB_USER 
ALTER SCHEMA public OWNER TO trisano_su;
GRANT USAGE ON SCHEMA trisano TO trisano_ro;

CREATE TABLE trisano.current_schema_name (
    schemaname TEXT NOT NULL
);
TRUNCATE TABLE trisano.current_schema_name;
INSERT INTO trisano.current_schema_name VALUES ('warehouse_a');

CREATE TABLE trisano.etl_success (
    success BOOLEAN,
    entrydate TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO trisano.etl_success (success) VALUES (FALSE);

CREATE TABLE trisano.formbuilder_tables (
    id SERIAL PRIMARY KEY,
    short_name TEXT,
    table_name TEXT,
    modified BOOLEAN DEFAULT TRUE
);
CREATE INDEX formbuilder_form_name
    ON trisano.formbuilder_tables (short_name);
CREATE UNIQUE INDEX formbuilder_table_name
    ON trisano.formbuilder_tables (table_name);
CREATE INDEX formbuilder_tables_modified
    ON trisano.formbuilder_tables (modified);

CREATE TABLE trisano.formbuilder_columns (
    formbuilder_table_name TEXT REFERENCES trisano.formbuilder_tables(table_name)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    column_name TEXT,
    orig_column_name TEXT
);
CREATE UNIQUE INDEX formbuilder_columns_ix
    ON trisano.formbuilder_columns (formbuilder_table_name, column_name);
CREATE INDEX formbuilder_column_orig_name
    ON trisano.formbuilder_columns (orig_column_name);

CREATE OR REPLACE FUNCTION trisano.shorten_identifier(TEXT) RETURNS TEXT AS $$
    SELECT
        CASE
            WHEN char_length($1) < 64 THEN $1
            ELSE substring($1 FROM 1 FOR 1) || regexp_replace(substring($1 from 2), '[AEIOUaeiou]', '', 'g')
        END;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION trisano.prepare_etl() RETURNS BOOLEAN AS $$
BEGIN
    RAISE NOTICE 'Preparing for ETL process by creating staging schema';
    EXECUTE 'DROP SCHEMA IF EXISTS staging CASCADE';
    CREATE SCHEMA staging;
    EXECUTE 'DROP SCHEMA IF EXISTS public CASCADE';
    CREATE SCHEMA public;
    TRUNCATE TABLE trisano.etl_success;
    INSERT INTO trisano.etl_success (success) VALUES (FALSE);
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION
    trisano.text_join(accum TEXT, newvalue TEXT, separator TEXT)
    RETURNS text AS
$$
DECLARE
    result TEXT DEFAULT '';
BEGIN
    IF accum IS NOT NULL AND accum != '' THEN
       result := accum || separator || newvalue;
    ELSE
       result := accum || newvalue;
    END IF;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE AGGREGATE trisano.text_join_agg (text, text) (
    sfunc = trisano.text_join,
    stype = text,
    initcond =''
);

CREATE OR REPLACE FUNCTION trisano.build_form_tables() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    questions_per_table     INTEGER := 200;
    form_name               TEXT;
    question_name           TEXT;
    question_count          INTEGER;
    cur_table_count         INTEGER;
    cur_table_name          TEXT;
    last_event_id           INTEGER;
    last_event_type         TEXT;
    insert_vals_clause      TEXT;
    insert_cols_clause      TEXT;
    tmprec                  RECORD;
    tmptext                 TEXT;
    tmpbool                 BOOLEAN;
    done                    BOOLEAN;
BEGIN
    -- This function creates tables for formbuilder data, in a series of steps:
    -- 
    -- 1) Develop schema for formbuilder tables
    -- 
    -- Forms are represented as one or more tables containing a column for
    -- each question. These tables contain up to questions_per_table columns.
    -- This step loops through each form name that has answers, and on each
    -- one, gets the lowercase short names of all answered questions
    -- associated with that form that aren't already assigned to a table
    -- (these assignments are recorded in the formbuilder_tables and
    -- formbuilder_columns tables in the trisano schema). These columns are
    -- added to the highest-numbered formbuilder table for this form (the only
    -- one that can possibly have room left for more columns) until it reaches
    -- questions_per_table columns, after which new tables are added. Any
    -- tables added or modified in this process are flagged so the metadata
    -- builder stuff can know to recreate that table.
    -- 
    -- 2) Build schema based on results from step 1
    --
    -- Having developed a schema in the last step, this step builds each of
    -- the tables defined in the formbuilder tables.
    --
    -- 3) Fill tables with data
    --
    -- Answers are sorted into the tables they belong to, and the data are
    -- inserted into the tables

    -- Loop through each form
    FOR form_name IN
                SELECT DISTINCT short_name
                FROM forms 
                WHERE short_name IS NOT NULL AND short_name != ''
                ORDER BY short_name LOOP

        RAISE NOTICE 'Processing form name %', form_name;

        -- Get highest-numbered table for this form, and count of its rows
        SELECT INTO cur_table_count count(*) FROM trisano.formbuilder_tables
            WHERE short_name = form_name;
        SELECT INTO tmprec id, table_name, count(*) AS count
            FROM trisano.formbuilder_tables t
            JOIN trisano.formbuilder_columns c
                ON (c.formbuilder_table_name = t.table_name)
            WHERE t.short_name = form_name
            GROUP BY id, table_name
            ORDER BY id DESC
            LIMIT 1;
        question_count := tmprec.count;
        cur_table_name := tmprec.table_name;

        -- If we haven't found a table, make sure we're set up to create a new
        -- one properly
        IF question_count IS NULL THEN
            question_count := questions_per_table;
            cur_table_count := 0;
        END IF;
        tmpbool := FALSE;

        RAISE NOTICE 'Found table name %, question count % for form name %', COALESCE(cur_table_name, '<null>'), question_count, form_name;

        -- Get columns represented in the forms that aren't already in the
        -- defined schema
        <<question_loop>>
        FOR tmprec IN SELECT DISTINCT
                    q.short_name,
                    regexp_replace(lower(q.short_name), '[^[:alnum:]_]', '_', 'g') AS safe_name
                FROM questions q JOIN answers a
                    ON (a.question_id = q.id AND a.text_answer IS NOT NULL AND a.text_answer != '')
                JOIN form_elements fe ON (fe.id = q.form_element_id)
                JOIN forms f
                    ON (f.id = fe.form_id AND f.short_name = form_name)
                WHERE NOT EXISTS (
                    SELECT 1 FROM trisano.formbuilder_columns tfc
                    JOIN trisano.formbuilder_tables tft
                        ON (tfc.formbuilder_table_name = tft.table_name
                            AND tft.short_name = form_name)
                    WHERE tfc.orig_column_name = q.short_name
                )
                AND q.short_name IS NOT NULL AND q.short_name != ''
                ORDER BY 1 LOOP 

            question_name := tmprec.safe_name;

            -- Create a new table if the current one is full
            IF question_count >= questions_per_table THEN
                cur_table_count := cur_table_count + 1;
                cur_table_name := 'formbuilder_' || lower(form_name) ||
                    '_' || cur_table_count;
                RAISE NOTICE 'Creating schema for table %, form %', cur_table_name, form_name;
                INSERT INTO trisano.formbuilder_tables (short_name,
                    table_name) VALUES (form_name, trisano.shorten_identifier(cur_table_name));
                question_count := 0;
                tmpbool := FALSE;
            END IF;

            -- The loop takes care of columns with different short_names that reduce to
            -- the same safe name
            <<add_column>>
            LOOP
                done := TRUE;
                BEGIN
                    INSERT INTO trisano.formbuilder_columns (formbuilder_table_name,
                        column_name, orig_column_name)
                        VALUES (cur_table_name, trisano.shorten_identifier(question_name), tmprec.short_name);

                    -- Make sure table is marked as modified, as necessary
                    IF NOT tmpbool THEN
                        UPDATE trisano.formbuilder_tables SET modified = TRUE WHERE
                            table_name = cur_table_name;
                        tmpbool := TRUE;
                    END IF;
                EXCEPTION
                    WHEN unique_violation THEN
                        question_name := question_name || '1';
                    done := FALSE;
                END;
                IF done THEN
                    EXIT add_column;
                END IF;
            END LOOP add_column;

            question_count := question_count + 1;
        END LOOP question_loop;
    END LOOP;

    -- Create tables to match the schema we've just built
    FOR tmprec IN SELECT table_name, trisano.text_join_agg(column_name, ' TEXT, col_') AS cols
        FROM trisano.formbuilder_tables t JOIN trisano.formbuilder_columns c
            ON t.table_name = c.formbuilder_table_name
        GROUP BY table_name ORDER BY table_name
    LOOP
        tmptext := 'CREATE TABLE ' || tmprec.table_name || ' (event_id INTEGER, type TEXT, col_'
                    || tmprec.cols || ' TEXT);';
        RAISE NOTICE 'Creating table %', tmprec.table_name;
        EXECUTE tmptext;
    END LOOP;

    -- Fill tables with data from answers
    FOR cur_table_name IN SELECT table_name FROM trisano.formbuilder_tables ORDER BY table_name LOOP
        RAISE NOTICE 'Filling table %', cur_table_name;
        tmptext := '';

        insert_cols_clause := ' (event_id, type';
        insert_vals_clause := '';
        last_event_id := NULL;
        last_event_type := NULL;

        -- Find all non-blank answers and associated event information
        FOR tmprec IN SELECT DISTINCT ON (a.event_id, e.type, tfc.column_name) a.event_id, e.type, tfc.column_name AS short_name, a.text_answer
                    FROM answers a JOIN events e ON (e.id = a.event_id)
                    JOIN questions q ON (a.question_id = q.id)
                    JOIN form_elements fe ON (fe.id = q.form_element_id)
                    JOIN forms f ON (f.id = fe.form_id)
                    JOIN trisano.formbuilder_columns tfc ON (tfc.orig_column_name = q.short_name)
                    WHERE tfc.formbuilder_table_name = cur_table_name
                    AND a.text_answer IS NOT NULL
                    AND a.text_answer != ''
                    ORDER BY a.event_id, e.type, short_name LOOP

            IF last_event_id IS NOT NULL AND last_event_id != tmprec.event_id THEN
                tmptext := 'INSERT INTO ' || cur_table_name || insert_cols_clause || ') VALUES (' || last_event_id || ', ''' || last_event_type || '''' || insert_vals_clause || ')';
                EXECUTE tmptext;
                insert_cols_clause := ' (event_id, type';
                insert_vals_clause := '';
            END IF;
            last_event_id   := tmprec.event_id;
            last_event_type := tmprec.type;

            insert_cols_clause := insert_cols_clause || ', ' || quote_ident('col_' || tmprec.short_name);
            insert_vals_clause := insert_vals_clause || ', ' || quote_literal(tmprec.text_answer);
        END LOOP;

        IF last_event_id IS NOT NULL THEN
            tmptext := 'INSERT INTO ' || cur_table_name || insert_cols_clause || ') VALUES (' || last_event_id || ', ''' || last_event_type || '''' || insert_vals_clause || ')';
            EXECUTE tmptext;
        END IF;

        -- Create indexes while we're here
        RAISE NOTICE 'Creating indexes for table %', cur_table_name;
        EXECUTE 'CREATE UNIQUE INDEX ' || trisano.shorten_identifier(cur_table_name || '_event_id_ix') || ' ON ' || cur_table_name || ' (event_id)';
        EXECUTE 'CREATE INDEX ' || trisano.shorten_identifier(cur_table_name || '_event_type_ix') || ' ON ' || cur_table_name || ' (type)';
    END LOOP;
END;
$$;
-- END OF trisano.build_form_tables()

CREATE OR REPLACE FUNCTION trisano.swap_schemas() RETURNS BOOLEAN AS $$
DECLARE
    cur_schema TEXT;
    new_schema TEXT;
    tmp TEXT;
    viewname TEXT;
    validetl BOOLEAN;
    orig_search_path TEXT;
BEGIN
    SELECT success INTO validetl FROM trisano.etl_success ORDER BY entrydate LIMIT 1;
    IF NOT validetl THEN
        RAISE EXCEPTION 'Last ETL process was, apparently, not valid. Not swapping schemas. See table trisano.etl_success.';
    END IF;

    SELECT schemaname FROM trisano.current_schema_name LIMIT 1 INTO cur_schema;
    IF cur_schema = 'warehouse_a' THEN
        new_schema = 'warehouse_b';
    ELSE
        new_schema = 'warehouse_a';
    END IF;
    RAISE NOTICE 'Production schema is %; will switch to %', cur_schema, new_schema;

    tmp := 'DROP SCHEMA IF EXISTS ' || new_schema || ' CASCADE';
    EXECUTE tmp;
    tmp := 'ALTER SCHEMA staging RENAME TO ' || new_schema;
    EXECUTE tmp;

    -- Create form builder tables
    SELECT INTO orig_search_path setting FROM pg_settings WHERE name = 'search_path';
    EXECUTE 'SET search_path = ' || new_schema;
    PERFORM trisano.build_form_tables();
    EXECUTE 'SET search_path = ' || orig_search_path;

    -- Drop views in trisano schema
    FOR viewname IN
      SELECT pg_class.relname
      FROM pg_class JOIN pg_namespace ON (pg_class.relnamespace = pg_namespace.oid)
      WHERE pg_namespace.nspname = 'trisano' AND pg_class.relkind = 'v'
      LOOP
        IF EXISTS
          (SELECT 1 FROM pg_class JOIN pg_namespace
          ON pg_namespace.oid = pg_class.relnamespace
          WHERE pg_class.relname = viewname AND pg_class.relkind = 'v') THEN
            -- CASCADE just in case there are dependencies
            tmp := 'DROP VIEW trisano.' || viewname || ' CASCADE';   
            EXECUTE tmp;
        END IF;
    END LOOP;

    -- Create a new view for each table in the current schema
    FOR viewname IN 
      SELECT pg_class.relname
      FROM pg_class JOIN pg_namespace ON (pg_class.relnamespace = pg_namespace.oid)
      WHERE pg_namespace.nspname = new_schema AND pg_class.relkind = 'r' AND relname NOT LIKE 'formtable_%'
      LOOP
        tmp := 'CREATE VIEW trisano.' || viewname || '_view AS SELECT * FROM ' || new_schema || '.' || viewname;
        EXECUTE tmp;
    END LOOP;

    -- Create event-type-specific views for each formtable* table
    FOR viewname IN
      SELECT pg_class.relname
      FROM pg_class JOIN pg_namespace ON (pg_class.relnamespace = pg_namespace.oid)
      WHERE pg_namespace.nspname = new_schema AND pg_class.relkind = 'r' AND relname LIKE 'formtable_%'
      LOOP
        tmp := 'CREATE VIEW trisano.' || viewname || '_morbidity_view AS SELECT * FROM ' || new_schema || '.' || viewname || ' WHERE type = ''MorbidityEvent''';
        EXECUTE tmp;
        tmp := 'CREATE VIEW trisano.' || viewname || '_place_view AS SELECT * FROM ' || new_schema || '.' || viewname || ' WHERE type = ''PlaceEvent''';
        EXECUTE tmp;
        tmp := 'CREATE VIEW trisano.' || viewname || '_contact_view AS SELECT * FROM ' || new_schema || '.' || viewname || ' WHERE type = ''ContactEvent''';
        EXECUTE tmp;
        tmp := 'CREATE VIEW trisano.' || viewname || '_encounter_view AS SELECT * FROM ' || new_schema || '.' || viewname || ' WHERE type = ''EncounterEvent''';
        EXECUTE tmp;
    END LOOP;

    -- Create a whole bunch of event-type-specific views. This helps Pentaho
    -- not have cycles in its graph of the schema
    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_patients_races_view AS
            SELECT pr.* FROM ' || new_schema || '.dw_patients_races pr
            JOIN ' || new_schema || '.dw_morbidity_patients p
                ON (p.id = pr.person_id)';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_patients_races_view AS
            SELECT pr.* FROM ' || new_schema || '.dw_patients_races pr
            JOIN ' || new_schema || '.dw_contact_patients p
                ON (p.id = pr.person_id)';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_reporting_agencies_view AS
            SELECT * FROM ' || new_schema || '.dw_events_reporting_agencies
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_reporting_agencies_view AS
            SELECT * FROM ' || new_schema || '.dw_events_reporting_agencies
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_diagnostic_facilities_view AS
            SELECT * FROM ' || new_schema || '.dw_events_diagnostic_facilities
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_diagnostic_facilities_view AS
            SELECT * FROM ' || new_schema || '.dw_events_diagnostic_facilities
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_reporters_view AS
            SELECT * FROM ' || new_schema || '.dw_events_reporters
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_reporters_view AS
            SELECT * FROM ' || new_schema || '.dw_events_reporters
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_treatments_events_view AS
            SELECT * FROM ' || new_schema || '.dw_events_treatments
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_treatments_events_view AS
            SELECT * FROM ' || new_schema || '.dw_events_treatments
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_treatments_view AS
            SELECT t.* FROM ' || new_schema || '.treatments t
            JOIN trisano.dw_events_treatments_view det
                ON (det.treatment_id = t.id AND det.dw_morbidity_events_id IS NOT NULL)';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_treatments_view AS
            SELECT t.* FROM ' || new_schema || '.treatments t
            JOIN trisano.dw_events_treatments_view det
                ON (det.treatment_id = t.id AND det.dw_contact_events_id IS NOT NULL)';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_lab_results_view AS
            SELECT * FROM ' || new_schema || '.dw_lab_results
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_lab_results_view AS
            SELECT * FROM ' || new_schema || '.dw_lab_results
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_encounters_lab_results_view AS
            SELECT l.* FROM ' || new_schema || '.lab_results l
            JOIN trisano.dw_encounters_labs_view del
                ON (del.dw_lab_results_id = l.id)';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_hospitals_view AS
            SELECT * FROM ' || new_schema || '.dw_events_hospitals
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_hospitals_view AS
            SELECT * FROM ' || new_schema || '.dw_events_hospitals
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_secondary_jurisdictions_view AS
            SELECT * FROM ' || new_schema || '.dw_secondary_jurisdictions
            WHERE dw_morbidity_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_contact_secondary_jurisdictions_view AS
            SELECT * FROM ' || new_schema || '.dw_secondary_jurisdictions
            WHERE dw_contact_events_id IS NOT NULL';

    EXECUTE
        'CREATE VIEW trisano.dw_enc_treatments_view AS
            SELECT tr.* FROM ' || new_schema || '.treatments tr
            JOIN trisano.dw_encounters_treatments_view det
                ON (det.dw_events_treatments_id = tr.id)';

    EXECUTE
        'CREATE VIEW trisano.dw_morbidity_jurisdictions_view AS
            SELECT p.*
            FROM ' || new_schema || '.places p
            INNER JOIN (
                SELECT DISTINCT j.id
                FROM ' || new_schema || '.places j
                LEFT JOIN trisano.dw_morbidity_events_view dme
                    ON (dme.investigating_jurisdiction_id = j.id
                        OR dme.jurisdiction_of_residence_id = j.id)
                LEFT JOIN trisano.dw_secondary_jurisdictions_view dsj
                    ON (dsj.jurisdiction_id = j.id AND dsj.dw_morbidity_events_id IS NOT NULL)
                WHERE dme.investigating_jurisdiction_id IS NOT NULL
                    OR dsj.dw_morbidity_events_id IS NOT NULL
            ) f
                ON (p.id = f.id)';
            
    EXECUTE
        'CREATE VIEW trisano.dw_contact_jurisdictions_view AS
            SELECT p.*
            FROM ' || new_schema || '.places p
            INNER JOIN (
                SELECT DISTINCT j.id
                FROM ' || new_schema || '.places j
                LEFT JOIN trisano.dw_contact_events_view dme
                    ON (dme.investigating_jurisdiction_id = j.id
                        OR dme.jurisdiction_of_residence_id = j.id)
                LEFT JOIN trisano.dw_secondary_jurisdictions_view dsj
                    ON (dsj.jurisdiction_id = j.id AND dsj.dw_contact_events_id IS NOT NULL)
                WHERE dme.investigating_jurisdiction_id IS NOT NULL
                    OR dsj.dw_morbidity_events_id IS NOT NULL
            ) f
                ON (p.id = f.id)';

    FOR viewname IN 
      SELECT relname
      FROM pg_class JOIN pg_namespace
      ON (pg_class.relnamespace = pg_namespace.oid)
      WHERE nspname = 'trisano' AND relkind = 'v'
      LOOP
        tmp := 'GRANT SELECT ON trisano.' || viewname || ' TO trisano_ro';
        EXECUTE tmp;
    END LOOP;

    UPDATE trisano.current_schema_name SET schemaname = new_schema;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
-- END OF trisano.swap_schemas()