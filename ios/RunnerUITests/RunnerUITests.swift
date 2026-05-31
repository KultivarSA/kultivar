// SR9 — Screenshot capture driver for Fastlane snapshot.
//
// This XCUITest walks through the key screens that should appear on
// the App Store listing.  Each `snapshot("…")` call writes a PNG to
// `fastlane/screenshots/<locale>/<DeviceClass>-NN_<name>.png` —
// `deliver` then uploads those PNGs into App Store Connect.
//
// The screen-walk order matters:  it's the order screenshots will
// appear in the App Store gallery unless you reorder them in App
// Store Connect after upload.  The current order tells the
// product story: Home → Plant Detail → Photo Timeline → Grow Report
// → Analytics → Settings/Privacy.  This is the order most users
// would meet the features in their first cycle.
//
// On first run from a clean checkout, generate the SnapshotHelper.swift
// file (Fastlane provides this automatically) with:
//
//     fastlane snapshot init
//
// from the `ios/` directory.  That writes `SnapshotHelper.swift`
// alongside this file.  The helper provides `setupSnapshot()` and
// `snapshot("…")`.
//
// The test relies on Kultivar's demo-data seed (SR8): launching the
// app fresh and tapping "Explore with sample data" puts the binary
// into a known state with 6 completed harvests, 4 active plants,
// and a populated analytics tab.  All `snapshot(…)` calls below
// assume that path was taken — see `setUp()` below.

import XCTest

class RunnerUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false

        // Snapshot helper hook — tells the launching app which
        // locale + device the harness is targeting so localized
        // strings + status-bar overrides line up.
        setupSnapshot(app)

        // Launch arguments / environment can be read by the Flutter
        // side via PlatformDispatcher to pre-seed test mode if you
        // want a fully deterministic run.
        app.launchArguments += ["UI-TESTING"]
        app.launch()

        // ── Onboarding short-circuit ──────────────────────────
        //
        // On a fresh simulator, the welcome screen comes up.  Tap
        // "Explore with sample data" (second CTA, lower button)
        // so the app lands in the seeded demo state without
        // forcing the test to create a plant by hand.
        if app.buttons["Explore with sample data"].waitForExistence(timeout: 8) {
            app.buttons["Explore with sample data"].tap()
        }

        // Allow the demo seed to populate (it triggers a repo load
        // + listener fan-out which Flutter renders on the next
        // frame).
        sleep(2)
    }

    func testCaptureMarketingScreens() {
        // ── 1. Home — the grow grid ────────────────────────────
        snapshot("01_Home")

        // ── 2. Tap the most recent plant → Plant Detail ──────
        //
        // The first card in the SliverList is the most-recently
        // started plant.  Tapping its title text is robust to
        // theme / layout changes; tapping the card itself is
        // brittle because the InkWell coordinates shift between
        // device classes.
        let firstActivePlant = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Blue Dream #3' OR label CONTAINS 'White Widow #2'")
        ).firstMatch
        if firstActivePlant.waitForExistence(timeout: 4) {
            firstActivePlant.tap()
            sleep(1)
            snapshot("02_PlantDetail")

            // ── 3. Scroll down to photo timeline + notes ──────
            app.swipeUp()
            sleep(1)
            snapshot("03_PlantNotes")

            // Back to Home for the next walk.
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // ── 4. Analytics tab ───────────────────────────────────
        //
        // Bottom-nav indices: 0 Home / 1 Analytics / 2 Archive /
        // 3 Notes / 4 Strains.  TabBarItem labels are localized so
        // we tap by `accessibilityIdentifier` if available; falling
        // back to index-based tab matching.
        let analyticsTab = app.buttons.matching(
            NSPredicate(format: "label IN {'Analytics','Analyse','Análisis','Analyses','Analisi','Ukuhlaziya'}")
        ).firstMatch
        if analyticsTab.waitForExistence(timeout: 3) {
            analyticsTab.tap()
            sleep(2)
            snapshot("04_Analytics")
        }

        // ── 5. Harvest archive — the cycle-completion payoff ──
        let archiveTab = app.buttons.matching(
            NSPredicate(format: "label IN {'Archive','Argief','Argivo','Archief','Ingobo-mlando'}")
        ).firstMatch
        if archiveTab.waitForExistence(timeout: 3) {
            archiveTab.tap()
            sleep(1)
            snapshot("05_HarvestArchive")
        }

        // ── 6. Grow Report on the most recent completed plant ──
        //
        // Each archive row has a "View Grow Report" button.  Tapping
        // the first row's button opens the PDF preview which is
        // the marketing money-shot for the "every cycle generates
        // a sharable report" feature.
        let firstHarvestRow = app.cells.firstMatch
        if firstHarvestRow.waitForExistence(timeout: 3) {
            firstHarvestRow.tap()
            sleep(2)
            snapshot("06_GrowReport")
        }

        // ── 7. Paywall — the Kultivar Pro tiers ────────────────
        //
        // Reach the paywall via Settings → Subscription.  This is
        // a required marketing surface for any app with paid tiers.
        // Navigate back to root first.
        while app.navigationBars.buttons.count > 0 &&
              app.navigationBars.buttons.element(boundBy: 0).label.contains("Back") {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Open Settings (long-press / tap depending on the device).
        let settingsButton = app.buttons.matching(
            NSPredicate(format: "label IN {'Settings','Einstellungen','Ajustes','Réglages','Impostazioni','Instellings','Izilungiselelo'}")
        ).firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            sleep(1)
            // Scroll until Subscription tile is visible.
            for _ in 0..<6 {
                let upgradeButton = app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS 'Upgrade to Pro' OR label CONTAINS 'Kultivar Pro'")
                ).firstMatch
                if upgradeButton.exists {
                    upgradeButton.tap()
                    sleep(2)
                    snapshot("07_Paywall")
                    break
                }
                app.swipeUp()
            }
        }
    }
}
