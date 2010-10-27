Feature: Staging Electronic Messages

  To process electonically submitted messages
  A user needs to be able to view messages and assign them to CMRs

  Scenario: Accessing the staging area with the right privileges
    Given I am logged in as a user with manage_staged_message privs
    When I follow "STAGING AREA"
    Then I should see the staging area page
    And I should not see "Create a staged message"

    Given I am logged in as a user with write_staged_message privs
    When I follow "STAGING AREA"
    Then I should see the staging area page
    And I should see "Create a staged message"

  Scenario: Accessing the staging area with the wrong privileges
    Given I am logged in as a user without staging area privs in the Unassigned jurisdiction
    Then I should not see the staging area link

    When I visit the staging area page directly
    Then I should get a 403 response

  Scenario: Viewing staged messages
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"

    When I visit the staged message show page

    Then I should see value "Lin, Genyao" in the message header
    And  I should see value "Specimen: BLOOD" in a message specimen
    And  I should see value "Collected: 2009-03-19" in a message specimen
    And  I should see value "ARUP LABORATORIES" in the message footer

    And  I should see value "Hepatitis Be Antigen" under label "Test type"
    And  I should see value "Positive" under label "Result"
    And  I should see value "Negative" under label "Test type"
    And  I should see value "2009-03-21" under label "Test Date"

  Scenario: Searching for matching events when none exist
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there are no matching entries

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    Then I should be sent to the search results page
    And I should see the staged message
    And I should not see any matching results

  Scenario: Searching for matching events when name only match is found
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a morbidity event with a matching name but no birth date

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    Then I should see matching results

  Scenario: Searching for matching events when name and birth date found
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a morbidity event with a matching name and birth date

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    Then I should see matching results

  Scenario: Assigning lab result to found event
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a morbidity event with a matching name and birth date
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 10000-1    | Blood Test  |
      | 20000-2    | Urine Test  |
      | 13954-3    | Hep-B Ag    |

    When I visit the staged message show page
      And I click 'Similar Events' for the staged message
      And I click the 'Assign lab result' link of the found event
    Then I should remain on the staged message show page
      And I should see a 'success' message

    When I visit the assigned-to event
    Then I should see the new lab result with 'Hep-B Ag'
    And  I should see a note for the assigned lab
    And  I should see a link back to the staged message

    When I navigate to the event edit page
    Then I should see a link back to the staged message

  Scenario: Assigning lab result to found contact event
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a contact event with a matching name and birth date
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 10000-1    | Blood Test  |
      | 20000-2    | Urine Test  |
      | 13954-3    | Hep-B Ag    |

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    And I click the 'Assign lab result' link of the found event
    Then I should remain on the staged message show page
    And I should see a 'success' message
    And I should not see the 'Similar Events' link
    And I should not see the 'Discard' link

    When I visit the assigned-to event
    Then I should see the new lab result with 'Hep-B Ag'
    And  I should see a note for the assigned lab
    And  I should see a link back to the staged message

  Scenario: Assigning lab result to new event
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a morbidity event with a matching name and birth date
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 10000-1    | Blood Test  |
      | 20000-2    | Urine Test  |
      | 13954-3    | Hep-B Ag    |

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    And I click 'Create a CMR from this message'
    Then I should remain on the staged message show page
    And I should see a 'success' message
    And I should not see the 'Similar Events' link
    And I should not see the 'Discard' link

    When I visit the assigned-to event
    Then I should see the patient information
    And I should see the new lab result with 'Hep-B Ag'
    And I should see a note for the assigned lab
    And I should see a link back to the staged message

  Scenario: Assigning lab result to a new event with an existing person
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a morbidity event with a matching name and birth date
    And that event also has a middle name of George
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 10000-1    | Blood Test  |
      | 20000-2    | Urine Test  |
      | 13954-3    | Hep-B Ag    |

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    And I click the 'Assign to new CMR using this person' link of the found event
    Then I should see a 'success' message

    When I visit the assigned-to event
    Then I should see the new lab result with 'Hep-B Ag'
    And I should see a middle name of George

  Scenario: Attempting to assign message with unknown LOINC code
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "UNKNOWN_LOINC"
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 10000-1    | Blood Test  |

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    And I click 'Create a CMR from this message'

    Then I should see a 'is unknown to TriSano' message
    And I should see a state of 'Unprocessable'

  Scenario: Attempting to assign message with unlinked LOINC code
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "UNLINKED_LOINC"
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 10000-1    |             |

    When I visit the staged message show page
    And I click 'Similar Events' for the staged message
    And I click 'Create a CMR from this message'

    Then I should remain on the staged message show page
    And I should see a 'is known but not linked' message
    And I should see a state of 'Unprocessable'

  Scenario: Discarding a message
    Given I am logged in as a user with manage_staged_message privs
    And I have the staged message "ARUP_1"
    And there is a morbidity event with a matching name and birth date

    When I visit the staged message show page
    And I click the 'Discard' link for the staged message
    Then I should see the staging area page
    And I should see a 'Staged message was discarded' message
    And I should not see the discarded message

  Scenario: Viewing a staged message with an OBX-23 field
    Given I am logged in as a super user
    And I have the staged message "realm_campylobacter_jejuni"
    When I visit the staged message show page
    Then I should see value "GHH Lab" in the message footer

  Scenario: Viewing a staged message without an OBX-23 field
    Given I am logged in as a super user
    And I have the staged message "arup_1"
    When I visit the staged message show page
    Then I should see value "ARUP LABORATORIES" in the message footer

  @pending
  Scenario: Assigning a staged message with a home phone number
    Given I am logged in as a super user
    And I have the staged message "realm_campylobacter_jejuni"
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 625-4      | Culture     |
    When I visit the staged message show page
    And I follow "Similar Events"
    And I follow "Create a CMR from this message"
    Then I should receive a 200 response
    And I should remain on the staged message show page
    And I should see value "Assigned" in the message footer

  @pending
  Scenario: Viewing a staged message with a home phone number
    Given I am logged in as a super user
    And I have the staged message "realm_campylobacter_jejuni"
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 625-4      | Culture     |
    When I visit the staged message show page
    And I follow "Similar Events"
    And I follow "Create a CMR from this message"
    And I visit the assigned-to event
    Then I should see "Home" under Telephones/Email on the Demographic tab

  @pending
  Scenario: Viewing a staged message with a cell phone number
    Given I am logged in as a super user
    And I have the staged message "realm_cj_cell_phone"
    And the following loinc code to common test types mapping exists
      | loinc_code | common_name |
      | 625-4      | Culture     |
    When I visit the staged message show page
    And I follow "Similar Events"
    And I follow "Create a CMR from this message"
    And I visit the assigned-to event
    Then I should see "Mobile" under Telephones/Email on the Demographic tab
