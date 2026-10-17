# duo-fortune-ball (working display name: Fold Fortune)

An original fortune toy for iPhone, designed first for iPhone Duo and usable on any iPhone running iOS 27.1 or later (the deployment target, needed for the hinge APIs).

Type a question on the outer display while the phone is closed. Open the phone and the answer unfolds on the inner display. On an iPhone without a hinge, tap to reveal instead.

> Original design. This project is an original work and is not affiliated with, endorsed by or derived from any toy brand, toy company or existing fortune toy. It uses its own name, shapes, characters, colours and answer wording.

## Design

- The fortune is a two-shell "seed pod" that opens with the hinge and reveals a glowing answer card. It is not a ball and does not use any numbered or liquid-filled toy imagery.
- Palette: eucalyptus green, wattle gold, ochre and cream.
- Answers are original wording, grouped by tone (yes, maybe, no, playful), and fully customisable.

## iPhone Duo APIs used

Apple's iPhone Duo APIs are public in the iOS 27.1 SDK and later. This project uses the real names:

| Need | API | Docs |
| --- | --- | --- |
| Hinge status and angle (SwiftUI) | `View.onHingeChange(isEnabled:_:)` giving `DeviceHingeContext`, whose `hinge` is a `DeviceHinge?` (nil on devices without a hinge) | [onHingeChange](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)), [DeviceHingeContext](https://developer.apple.com/documentation/swiftui/devicehingecontext), [DeviceHinge](https://developer.apple.com/documentation/swiftui/devicehinge) |
| Hinge status values | `DeviceHinge.Status`: `.closed`, `.partiallyOpen`, `.fullyOpen`; `DeviceHinge.angle` is an `Angle` | [DeviceHinge.Status](https://developer.apple.com/documentation/swiftui/devicehinge/status-swift.struct) |
| Hinge (UIKit equivalent, not used yet) | `UIHingeInteraction`, `UIHinge` | [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction), [UIHinge](https://developer.apple.com/documentation/uikit/uihinge) |
| Fold region for layout | `ReservedRegion` (kinds `.division` and `.occlusion`) via `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | [ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion) |
| Split layouts across the fold | `ArrangementView` | [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview) |

Background: [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/), [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/).

There is no dedicated "outer display" API. Apple's guidance is that the outer display behaves like a normal compact width iPhone, so the app treats hinge status `.closed` as "asking on the outer display" and uses size classes for layout. Apple advises using hinge data for live interactions and effects and the arrangement and reserved region APIs for layout, which is what this app does.

The app target adapts `onHingeChange` into a small `FoldStateService` protocol in the `FortuneCore` package. That keeps the logic testable on Linux with a scriptable mock, and gives a clean fallback (`.unavailable`) on iPhones without a hinge, where the app uses tap to reveal.

## Haptics and sound

On iPhone Duo, opening the phone gives a light haptic tick for every 15 degrees of hinge travel and a short pod creak as it starts to open. The reveal has its own haptic and chime for each tone: success for yes, warning for no, and a soft tap for maybe and playful. In tap mode only the reveal gives feedback.

Sounds use an ambient audio session, so the silent switch mutes them, and they can be turned off in the answers sheet. All sounds are synthesised by `scripts/make_sounds.py` (see `App/Resources/Sounds/CREDITS.md`).

## Layout

```
project.yml                  XcodeGen spec for the app (generate the .xcodeproj, it is not committed)
App/Sources                  SwiftUI app target
App/Resources                Asset catalogue and sounds
App/Tests                    App unit tests (need a Mac)
scripts                      Sound synthesis script
Packages/FortuneCore         Pure Swift logic package, no SwiftUI or UIKit, builds on Linux
.github/workflows/ios.yml    CI: FortuneCore tests on Linux, plus FortuneCore tests, app build and app tests on the hosted xcode-27 image
```

## Not wired up yet

`FortuneCore.ShareCard` (the share text and card model) is built and tested but not used by the app yet. There is no share button until a follow-up adds `ShareLink`.

## Build

Logic package (Linux or macOS):

```sh
cd Packages/FortuneCore
swift build
swift test
```

App (macOS with Xcode 27.1 or later):

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project FoldFortune.xcodeproj -scheme FoldFortune \
  -destination 'platform=iOS Simulator,name=<an iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO build test
```

Use the iPhone Duo simulator in Xcode's Device Hub to open, close and fold the device.

The deployment target is iOS 27.1 because that is where the hinge APIs start.

## Licence

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 Justin Middler.
