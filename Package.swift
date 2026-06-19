// swift-tools-version: 5.9
import PackageDescription

/// Reference manifest for Habfitise third-party dependencies.
/// The iOS app target resolves these via Xcode SPM integration in Habfitise.xcodeproj.
let package = Package(
    name: "HabfitiseDependencies",
    platforms: [
        .iOS(.v17)
    ],
    products: [],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "5.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0")
    ],
    targets: []
)
