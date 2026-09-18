// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PublicAvailabilitySchedule",
    defaultLocalization: "ru",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AvailabilitySchedule", targets: ["ScheduleApp"])],
    targets: [
        .target(name: "ScheduleCore"),
        .executableTarget(name: "ScheduleApp", dependencies: ["ScheduleCore"], resources: [.process("Resources")]),
        .testTarget(name: "ScheduleCoreTests", dependencies: ["ScheduleCore"]),
        .testTarget(name: "ScheduleAppTests", dependencies: ["ScheduleApp", "ScheduleCore"])
    ]
)
