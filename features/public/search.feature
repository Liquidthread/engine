Feature: Search
  As a visitor
  In order to find relevant content
  I want to be able to search through content types

  Background:
    Given I have a custom model named "Articles" with
      | label | type   | required |
      | Copy  | text   | true     |
      | Title | string | true     |

    And a page named "search-form" with the template:
      """
      <html>
        <head></head>
        <body>
          <form action="{{ page.permalink }}" method="get">
          <input type="text" name="query"/>
          </form>
          <ul id="search_results">

          </ul>
        </body
      </html>
      """
