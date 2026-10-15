# Milestones with deadlines
 
## 1. Project specification
 
**Deadline:** 14.09-18.09
 
- [x] Project topic name and description
- [x] Screen diagram with transitions
- [x] Technology stack (what you use on the frontend)
- [x] Pitfalls (datasets, open APIs, complex logic)
## 2. Authorization + Registration
 
**Deadline:** 28.09-02.10 (originally due 25.09, extended to 02.10)
 
- [x] User model
- [x] Login/registration screen
- [x] A screen that shows whether you are logged in or not
- [x] Session handling (the user is not logged out when the page is refreshed. There is a logout button that ends the session)
## 3. UI Kit
 
**Deadline:** 28.09-02.10
 
Show the markup and styles for all interface elements related to the core functionality of the project. For example, for a Moodle-like service these would be: a form for choosing an answer, a form for entering answer options with an "add option" button, a free-text input form, a test card, etc.
 
Format: a separate page where you can scroll through all kinds of buttons, forms and fonts. Alternatively, screens that are already built in the form they will have in the final project, but "with placeholders".
 
- [x] UI Kit is ready
## 4. Models and model tests
 
**Deadline:** 05.10-09.10
 
- [x] Database schema (mandatory at this stage)
- [ ] Migrations + models. Models must include validations, associations and business logic methods
- [ ] Automated tests for business logic methods (mandatory), for validations and associations (optional). Ideally there should be at least 2-3 test files with 2-3 "contexts" in each
## 5. User happy path
 
**Deadline:** 19.10-23.10
 
As a user, I can click through the entire core functionality of your project. Validations for various error cases may be missing, some "branches" or part of the non-core functionality may be missing. For example, in a Moodle-like service with test creation and test taking, I want to see the ability to create the simplest possible test and take it from another account. But there may not yet be different question types, question commenting, or auto-grading.
 
- [ ] User happy path is ready
## 6. Integration tests
 
**Deadline:** 26.10-30.10
 
Detailed tests for the happy path + 2-3 branches off it (in the example above, a case could be: a user without edit permissions tries to edit a test -> we return an error).
 
- [ ] Detailed tests for the happy path
- [ ] Tests for 2-3 branches off the happy path
## 7. Page with live (and partial) data updates
 
**Deadline:** 02.11-06.11
 
Use WebSockets. Action Cable on the server, on the client it depends on the chosen stack. For Hotwire I expect Turbo Streams + Turbo Frames here.
 
Example pages: a leaderboard that updates in real time; a page with comments loaded without refreshing the page; a chat with the owner of a booking; a likes counter.
 
- [ ] Page with live data updates is ready
