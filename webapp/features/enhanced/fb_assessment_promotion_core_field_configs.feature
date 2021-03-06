Feature: Forms remain attached when assessments are promoted to morbidity events

  To allow for a more relevant event form
  An investigator should have forms remain a part of promoted events

  Background:
    Given a lab named "Labby"


  Scenario: When an AE is promoted to a CMR, forms configs still apply
    Given I am logged in as a super user
    And a common test type named "Common Test Type"
    And a assessment event form exists
    And that form has core field configs configured for all core fields
    And that form is published
    And a assessment event exists with a disease that matches the form

    When I am on the assessment event edit page
     And I fill in enough assessment event data to enable all core fields to show up in show mode
     And I save and continue
     And I am on the assessment event edit page

     And I answer all core field config questions
     And I save and continue
     And I promote the assessment to a morbidity event
     And I am on the morbidity event edit page

    Then I should see all of the promoted core field config questions
     And I should see all promoted core field config answers

  Scenario: When an AE is promoted to a CMR, core follow ups remain part of promoted event
    Given I am logged in as a super user
    And a assessment event form exists
    And that form has core follow ups configured for all core fields
    And that form is published
    And a assessment event exists with a disease that matches the form
    And I am on the assessment event edit page
# TODO Jay Core follow ups are broken, fields do not properly display
#   When I answer all of the core follow ups with a matching condition
#    And I save and continue
#    And I am on the assessment event edit page
#    And I answer all core follow up questions
#    And I save and continue
#    And I promote the assessment to a morbidity event
#    And I am on the morbidity event edit page

#   Then I should see all of the core follow up questions
#    And I should see all follow up answers
   
#   When I am on the morbidity event show page
#   Then I should see all of the core follow up questions
#    And I should see all follow up answers
