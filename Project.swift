import ProjectDescription

let project = Project(
    name: "KidRideRewards",
    targets: [
        .target(
            name: "KidRideRewards",
            destinations: .iOS,
            product: .app,
            bundleId: "com.kidride.rewards",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": .dictionary([:]),
                    "NSLocationWhenInUseUsageDescription": .string("KidRide Rewards uses your location to track rides and keep families safe.")
                ]
            ),
            sources: [
                "KidRideRewardsApp.swift",
                "Models/**",
                "Services/**",
                "ViewModels/**",
                "Views/**"
            ]
        )
    ]
)
