# Copyright (C) 2007, 2008, The Collaborative Software Foundation
#
# This file is part of TriSano.
#
# TriSano is free software: you can redistribute it and/or modify it under the 
# terms of the GNU Affero General Public License as published by the 
# Free Software Foundation, either version 3 of the License, 
# or (at your option) any later version.
#
# TriSano is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License 
# along with TriSano. If not, see http://www.gnu.org/licenses/agpl-3.0.txt.

class MorbidityEventsController < EventsController

  def auto_complete_for_event_reporting_agency
    entered_name = params[:morbidity_event][:active_reporting_agency][:active_secondary_entity][:place][:name]
    @items = Place.find(:all, :select => "DISTINCT ON (entity_id) entity_id, name", 
      :conditions => [ "LOWER(name) LIKE ? and place_type_id IN 
                       (SELECT id FROM codes WHERE code_name = 'placetype' AND the_code IN ('H', 'L', 'C'))", entered_name.downcase + '%'],
      :order => "entity_id, created_at ASC, name ASC",
      :limit => 10
    )
    render :inline => '<ul><% for item in @items %><li id="reporting_agency_id_<%= item.entity_id %>"><%= h item.name %></li><% end %></ul>'
  end

  def auto_complete_for_lab_name
    entered_name = params[:morbidity_event][:new_lab_attributes].first[:name]
    @items = Place.find(:all, :select => "DISTINCT ON (entity_id) entity_id, name", 
      :conditions => [ "LOWER(name) LIKE ? and place_type_id IN 
                       (SELECT id FROM codes WHERE code_name = 'placetype' AND the_code = 'L')", entered_name.downcase + '%'],
      :order => "entity_id, created_at ASC, name ASC",
      :limit => 10
    )
    render :inline => '<ul><% for item in @items %><li id="lab_name_id_<%= item.entity_id %>"><%= h item.name %></li><% end %></ul>'
  end

  def index
    conditions = ["participations.secondary_entity_id IN (?)", User.current_user.jurisdiction_ids_for_privilege(:view_event)]

    unless params[:states].nil?
      state_ids = get_allowed_states(params[:states])
      if state_ids.empty?
        render :file => "#{RAILS_ROOT}/public/404.html", :layout => 'application', :status => 404 and return
      else
        conditions[0] += " AND event_status_id IN (?)"
        conditions << state_ids
      end
    end

    @events = MorbidityEvent.find(:all, 
                                  :include => :jurisdiction, 
                                  :select => "jurisdiction.secondary_entity_id", 
                                  :conditions => conditions)

    respond_to do |format|
      format.html # { render :template => "events/index" }
      format.xml  { render :xml => @events }
      format.csv
    end
  end

  def show
    # @event initialized in can_view? filter

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @event }
      format.csv
      format.print
    end
  end

  def new
    unless User.current_user.is_entitled_to?(:create_event)
      render :text => "Permission denied: You do not have privileges to create a CMR", :status => 403
      return
    end

    # Debt:  Get rid of this monstrosity and replace with #build calls here in the controller.
    #        Get rid of corresponding setters
    @event = MorbidityEvent.new(
      :event_onset_date => Date.today,
      :disease          => {}, 
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
            :primary_yn_id => ExternalCode.yes_id,
            :location_type_id => Code.find_by_code_name_and_code_description('locationtype', "Address Location Type").id
          },
          :telephone_entities_location => {
            :primary_yn_id => ExternalCode.no_id,
            :location_type_id => Code.find_by_code_name_and_code_description('locationtype', "Telephone Location Type").id
          },
          :address => {}, 
          :telephone => {} 
        }
      },
      :active_jurisdiction => {}
    )

    # Push this into the model
    @event.labs << Participation.new_lab_participation
    @event.hospitalized_health_facilities << Participation.new_hospital_participation
    @event.diagnosing_health_facilities << Participation.new_diagnostic_participation
    @event.contacts << Participation.new_contact_participation
    @event.patient = Participation.new_patient_participation
    
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
    @event = MorbidityEvent.new(params[:morbidity_event])
    @contact_events = ContactEvent.initialize_from_morbidity_event(@event)

    unless User.current_user.is_entitled_to_in?(:create_event, @event.active_jurisdiction.secondary_entity_id)
      render :text => "Permission denied: You do not have create privileges for this jurisdiction", :status => 403
      return
    end
    
    # Allow for test scripts and developers to jump directly to the "under investigation" state
    if RAILS_ENV == "production"
      @event.event_status = ExternalCode.find_by_the_code("NEW")
    end

    respond_to do |format|
      if @event.save && @contact_events.all? { |contact| contact.save }
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
    prep_multimodels_for(:morbidity_event)

    # Do this assign and a save rather than update_attributes in order to get the contacts array (at least) properly built
    @event.attributes = params[:morbidity_event]
    @contact_events = ContactEvent.initialize_from_morbidity_event(@event)

    respond_to do |format|
      if @event.save && @contact_events.all? { |contact| contact.save }
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

  # Route an event from one jurisdiction to another
  def jurisdiction
 
    @event = MorbidityEvent.find(params[:id])

    # user cannot route events _from_ a jurisdiction for which they do not have the 'route_event_to_any_lhd' privilege
    unless User.current_user.is_entitled_to_in?(:route_event_to_any_lhd, @event.active_jurisdiction.secondary_entity_id)
      render :text => "Permission denied: You do not have sufficent privileges to route events from this jurisdiction", :status => 403
      return
    end

    # user cannot route events _to_ a jurisdiction for which they do not have the 'create_event' privilege
    unless User.current_user.is_entitled_to_in?(:create_event, params[:jurisdiction_id])
      render :text => "Permission denied: You do not have sufficent privileges to route events to this jurisdiction", :status => 403
      return
    end

    begin
      @event.route_to_jurisdiction(params[:jurisdiction_id])
      redirect_to request.env["HTTP_REFERER"]
    rescue Exception => ex
      @event.errors.add_to_base('Unable to route CMR: ' + ex.message)
      render :action => "show"
    end
  end

  def state
    @event = MorbidityEvent.find(params[:id])
    event_status_id = params[:morbidity_event].delete(:event_status_id)

    # Determine what privileges are required to change to the passed in state
    priv_required = Event.get_required_privilege(ExternalCode.event_code_str(event_status_id))

    # If nothing came back, then the passed in state was malformed
    if priv_required.nil?
      render :text => "Bad state", :status => 403
      return
    end

    # Check if the user is allowed to change the event to the passed in state
    unless User.current_user.is_entitled_to_in?(priv_required, @event.active_jurisdiction.secondary_entity_id)
      render :text => "Permission denied: You do not have sufficent privileges to make this change", :status => 403
      return
    end
    
    # Check if the state transition is legal. E.g: Legal -> "accepted by LHD" to "assigned to investigator".  Illegal -> "accepted by LHD" to "investigation complete"
    unless @event.legal_state_transition?(event_status_id.to_i)
      render :text => "Illegal State Transition", :status => 409
      return
    end

    # event_status_id is protected from mass update, set individually
    @event.event_status_id = event_status_id

    # A status change may be accompanied by other values such as an event queue, set them
    @event.attributes = params[:morbidity_event]

    if @event.save
      redirect_to request.env["HTTP_REFERER"]
    else
      flash[:notice] = 'Unable to change state of CMR.'
      redirect_to cmrs_path
    end
  end

  private
  
  def prepopulate
    # Perhaps include a message if we know the names were split out of a full text search
    @event.active_patient.active_primary_entity.person_temp.first_name = params[:first_name]
    @event.active_patient.active_primary_entity.person_temp.middle_name = params[:middle_name]
    @event.active_patient.active_primary_entity.person_temp.last_name = params[:last_name]
    @event.active_patient.active_primary_entity.person_temp.birth_gender = ExternalCode.find(params[:gender]) unless params[:gender].blank? || params[:gender].to_i == 0
    @event.active_patient.active_primary_entity.address.city = params[:city]
    @event.active_patient.active_primary_entity.address.county = ExternalCode.find(params[:county]) unless params[:county].blank?
    @event.active_jurisdiction.secondary_entity_id = params[:jurisdiction_id] unless params[:jurisdiction_id].blank?
    @event.active_patient.active_primary_entity.person_temp.birth_date = params[:birth_date]
    @event.disease.disease_id = params[:disease]
  end
  
  # Expects string of space separated event states e.g. new, acptd-lhd, etc.
  def get_allowed_states(states)
    query_states = states.split(" ").collect { |state| state.upcase } 
    system_states = ExternalCode.find_all_by_code_name('eventstatus')
    system_states.collect { |system_state| query_states.include?(system_state.the_code) ? system_state.id : nil }.compact!
  end
end
