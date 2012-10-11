Feature: Filter
  As a designer
  In order to make dealing with multiple filter strings based on query paramters easier
  I want to be able to define lists of filters and appropriate markup

  Background:
    Given I have the site: "test site" set up
    And I have a custom model named "Articles" with
      | label | type   | required |
      | Title | string | true     |
      | Body  | text   | false    |
      | Type  | select | false    |
    And I have "type_1, type_2" as "Type" values of the "Articles" model
    And I have a custom model named "Projects" with
      | label       | type   | required |
      | Name        | string | true     |
      | Description | text   | false    |
    And I have entries for "Articles" with
      | title       | body           | type   |
      | Hello world | Lorem ipsum    | type_1 |
      | Lorem ipsum | Lorem ipsum... | type_2 |
    And I have entries for "Projects" with
      | name            | description    |
      | My sexy project | Lorem ipsum    |
      | Foo project     | Lorem ipsum... |
      | Bar project     | Lorem ipsum... |
      | Baz project     | Lorem ipsum... |

  Scenario: Filtering a collection
    Given a page named "filter-text-field" with the template:
    """
    {% filter contents.articles fields: [type] %}
    Hello
    {% endfilter %}
    """
    # And I set up a many_to_many relationship between "Articles" and "Projects"
    # And I attach the "My sexy project" project to the "Hello world" article
    #And I attach the "Hello world" article to the "Baz project" project
    # And I attach the "Hello world" article to the "Foo project" project
    When I view the rendered page at "/filter-text-field?articles[type][]=type_2&articles[type][]=type_1"
    Then the rendered output should look like:
    """

    Hello

    """
