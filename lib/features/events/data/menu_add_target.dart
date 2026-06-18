/// What the event Menu's single bottom "add" button adds, derived from the open
/// accordion section (Spec 017 §A.1).
///
/// The Menu accordion opens one section at a time, so the bottom action is
/// unambiguous: the Begudes section open → add a drink; a dish category open or
/// everything collapsed → add a dish.
library;

enum MenuAddTarget { dish, drink }

MenuAddTarget menuAddTargetFor({required bool drinksSectionOpen}) =>
    drinksSectionOpen ? MenuAddTarget.drink : MenuAddTarget.dish;
