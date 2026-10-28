# Movement Quest — AI Feature Documentation

## 1. Feature Overview

Movement Quest includes a Progressive Quest Guide that helps users decide how to adjust their workout goals based on previous activities.

The guide looks at completed workout history and compares the results with the user's target duration. It then provides a recommendation that the user can choose to follow or ignore.

## 2. Why We Included This Feature

We wanted Movement Quest to do more than just record workouts. The Progressive Quest Guide gives users feedback based on their progress.

Instead of using an online AI service, we implemented a local rule-based recommendation system. This makes the recommendations predictable, explainable, and available without an internet connection.

The guide is not a machine learning model or a cloud AI chatbot.

## 3. How It Works

The guide uses the user's workout plan and completed activity history.

It follows these general rules:

1. If fewer than three completed activities are available for the selected activity type, the guide explains that there is not enough history for a progress-based recommendation.
2. If recent activities fall below the target duration, the guide suggests keeping the current target.
3. If recent activities consistently meet or exceed the target duration, the guide suggests a small increase, such as moving from 30 to 35 minutes.
4. Recommendations are based on the relevant activity type, so walking activities should not influence cycling recommendations.
5. The guide does not automatically modify workout plans or saved goals.

## 4. Baseline and User Control

Without the Progressive Quest Guide, users can still create plans, track activities, view history, and manage their goals.

The guide adds optional recommendations but does not replace any core application functionality.

Users can ignore the recommendation or manually edit their workout plan. Their original goals remain unchanged unless they decide to update them.

## 5. Evaluation and Testing

| Test | Scenario | Expected Behavior | Result |
|---|---|---|---|
| 1 | Fewer than three completed walking activities | Explain that there is insufficient history | Passed |
| 2 | Recent walking activities below the target | Recommend maintaining the current target | Passed |
| 3 | Three walking activities meeting or exceeding a 30-minute target | Suggest a small increase | Passed — suggested 35 minutes |
| 4 | Recommendation suggests increasing duration | Keep the original plan unchanged unless manually edited | Passed — plan remained 30 minutes and 2 miles |
| 5 | Cycling plan with walking history but no cycling history | Do not use walking history to recommend cycling progression | Passed |

## 6. Counterexample and Limitations

The guide does not always recommend increasing a workout target.

For example, if the user has completed several activities below the target, recommending a harder workout would not match their recent progress. In this case, the guide recommends maintaining the current target.

The guide also has limitations. It uses a small amount of workout history and simple rules rather than advanced analysis. It does not evaluate medical conditions, injury risks, or other health factors.

Its recommendations are general activity suggestions, not medical advice.

## 7. Offline Functionality

The Progressive Quest Guide uses locally stored workout information and does not require an external AI API.

Movement Quest was tested on an Android emulator and a physical Android phone. Offline plan creation and persistence were verified on the phone using Airplane Mode.

The guide's logic is designed to operate locally without an internet connection.

## 8. Conclusion

The Progressive Quest Guide adds a simple recommendation feature to Movement Quest while keeping the user in control.

It uses explainable rules, completed activity history, and local storage to provide suggestions without depending on cloud services.