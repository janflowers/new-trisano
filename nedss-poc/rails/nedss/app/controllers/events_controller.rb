class EventsController < ApplicationController

  before_filter :can_update?, :only => [:edit, :update, :destroy]
  before_filter :can_view?, :only => [:show]
  before_filter :get_investigation_forms, :only => [:edit]
  
  def auto_complete_for_event_reporting_agency
    entered_name = params[:event][:active_reporting_agency][:active_secondary_entity][:place][:name]
    @items = Place.find(:all, :select => "DISTINCT ON (entity_id) entity_id, name", 
      :conditions => [ "LOWER(name) LIKE ? and place_type_id IN 
                       (SELECT id FROM codes WHERE code_name = 'placetype' AND the_code IN ('H', 'L', 'C'))", entered_name.downcase + '%'],
      :order => "entity_id, created_at ASC, name ASC",
      :limit => 10
    )
    render :inline => '<ul><% for item in @items %><li id="reporting_agency_id_<%= item.entity_id %>"><%= h item.name %></li><% end %></ul>'
  end

  def index
    @events = Event.find(:all, 
      :include => :jurisdiction, 
      :select => "jurisdiction.secondary_entity_id", 
      :conditions => ["participations.secondary_entity_id IN (?)", User.current_user.jurisdiction_ids_for_privilege(:view)])

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @events }
      format.csv
    end
  end

  def show
    @event = Event.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @event }
      format.csv
    end
  end

  def new
    # Debt:  Get rid of this monstrosity and replace with #build calls here in the controller.
    #        Get rid of corresponding setters
    @event = Event.new(
      :event_onset_date => Date.today,
      :disease          => {}, 
      :active_patient   => { 
        :active_primary_entity => { 
          :person => {}, 
          :entities_location => { 
            :entity_location_type_id => ExternalCode.unspecified_location_id,
            :primary_yn_id => ExternalCode.yes_id 
          }, 
          :address => {}, 
          :telephone => {}
        }, 
      },
      :active_reporting_agency => { 
        :secondary_entity_id => nil,
        :active_secondary_entity => { 
          :place => {},
          :entities_location => {}, 
          :address => {}, 
          :telephone => {}
        }
      },
      :active_reporter => { 
        :active_secondary_entity => { 
          :person => {}, 
          :entities_location => { 
            :entity_location_type_id => ExternalCode.unspecified_location_id,
            :primary_yn_id => ExternalCode.yes_id 
          }, 
          :address => {}, 
          :telephone => {} 
        }
      },
      :active_jurisdiction => {}
    )

    # Push this into the model
    lab = @event.labs << Participation.lab_object_tree
    
    prepopulate if !params[:from_search].nil?

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @event }
    end
  end

  def edit
    # Via filters above #can_update? is called which loads up @event with the found event.
    # Nothing to do here.
  end

  def create
    # params[:event].delete("active_reporter") if params[:event][:active_reporter][:active_secondary_entity][:person].values_blank?
    @event = Event.new(params[:event])
    
    unless User.current_user.is_entitled_to_in?(:update, @event.active_jurisdiction.secondary_entity_id)
      render :text => "Permission denied: You do not have update privileges for this jurisdiction", :status => 403
      return
    end
    
    respond_to do |format|
      if @event.save
        flash[:notice] = 'CMR was successfully created.'
        format.html { redirect_to(cmr_url(@event)) }
        format.xml  { render :xml => @event, :status => :created, :location => @event }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    params[:event][:existing_lab_attributes] ||= {}

    respond_to do |format|
      if @event.update_attributes(params[:event])
        flash[:notice] = 'CMR was successfully updated.'
        format.html { redirect_to(cmr_url(@event)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    head :method_not_allowed
  end

  private
  
  def prepopulate
    # Perhaps include a message if we know the names were split out of a full text search
    @event.active_patient.active_primary_entity.person.first_name = params[:first_name]
    @event.active_patient.active_primary_entity.person.middle_name = params[:middle_name]
    @event.active_patient.active_primary_entity.person.last_name = params[:last_name]
    @event.active_patient.active_primary_entity.person.birth_gender = ExternalCode.find(params[:gender]) unless params[:gender].blank? || params[:gender].to_i == 0
    @event.active_patient.active_primary_entity.address.city = params[:city]
    @event.active_patient.active_primary_entity.address.county = ExternalCode.find(params[:county]) unless params[:county].blank?
    @event.active_jurisdiction.secondary_entity_id = params[:jurisdiction_id] unless params[:jurisdiction_id].blank?
    @event.active_patient.active_primary_entity.person.birth_date = params[:birth_date]
    @event.disease.disease_id = params[:disease]
  end
  
  def can_update?
    @event ||= Event.find(params[:id])
    unless User.current_user.is_entitled_to_in?(:update, @event.active_jurisdiction.secondary_entity_id)
      render :text => "Permission denied: You do not have update privileges for this jurisdiction", :status => 403
      return
    end
  end
  
  def can_view?
    @event = Event.find(params[:id])
    unless User.current_user.is_entitled_to_in?(:view, @event.active_jurisdiction.secondary_entity_id)
      render :text => "Permission denied: You do not have view privileges for this jurisdiction", :status => 403
      return
    end
  end

  def get_investigation_forms
    @event ||= Event.find(params[:id])
    @event.get_investigation_forms
  end
  
end
