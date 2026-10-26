# Movement Quest

Movement Quest is a Flutter mobile application designed to help users plan, track, and review their outdoor physical activities. Users can create workout plans, record completed activities, view their progress, and receive optional recommendations based on their activity history.

The application is designed to work offline, allowing users to manage their workout information without needing an internet connection.

## Features

- **Home:** Displays an overview of completed activities, total workout time, distance, and weekly progress.
- **Plans:** Create, view, edit, and delete workout plans with activity type, target duration, target distance, and notes.
- **Track:** Record activities such as walking, running, cycling, and hiking.
- **History:** View previous activities, update workout records, and delete entries.
- **Settings:** Set a weekly activity goal and save preferences between app sessions.
- **Progressive Quest Guide:** Provides optional workout recommendations based on recent completed activities.

## Technologies Used

- Flutter and Dart
- SQLite (`sqflite`) for local database storage
- SharedPreferences for saving user settings
- Android emulator and physical Android device for testing

## How the App Works

Users can create workout plans with a target duration and distance. After completing an activity, they can save the actual time, distance, and notes.

Completed activities are stored locally using SQLite and can be reviewed in the History screen. Users can also edit or delete their records.

The Home screen displays activity statistics and progress toward the weekly activity goal.

The Progressive Quest Guide compares recent completed activities with workout targets and provides optional suggestions. Users remain in control of their workout goals.

## Running the Project

1. Install Flutter and the Android development tools.
2. Clone this repository:

   ```bash
   git clone https://github.com/eyobedmerhawi/movement-quest.git
   ```

3. Open the project directory:

   ```bash
   cd movement-quest
   ```

4. Install dependencies:

   ```bash
   flutter pub get
   ```

5. Connect an Android device or start an Android emulator.
6. Run the application:

   ```bash
   flutter run
   ```

## Offline Storage

Movement Quest uses SQLite to save workout plans and completed activity records. SharedPreferences stores the user's weekly activity goal.

The application can be used without an internet connection, and saved information remains available after closing and reopening the app.

## Testing

The application has been tested on an Android emulator and a physical Android phone.

Testing completed so far includes:

- Creating, editing, and deleting workout plans
- Recording, editing, and deleting completed activities
- Checking dashboard statistics
- Saving and restoring weekly activity goals
- Verifying that activity history remains after deleting a workout plan
- Testing offline plan creation and persistence
- Testing initial Progressive Quest Guide recommendations

## Project Information

**Project:** Project One — Movement Quest

**Developer:** Eyobed Gebregziabher

**Platform:** Android (Flutter)