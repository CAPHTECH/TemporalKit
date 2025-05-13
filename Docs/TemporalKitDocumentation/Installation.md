# TemporalKit Installation Guide

This guide explains how to add and configure TemporalKit in your Swift projects.

## Requirements

TemporalKit works with the following environment:

- Swift 5.9 or later
- iOS 16.0 or later
- macOS 13.0 or later
- Xcode 15.0 or later

## Installation with Swift Package Manager

TemporalKit is primarily distributed through Swift Package Manager (SPM). You can add it using the following steps:

### Adding to an Xcode Project

1. Open your project in Xcode
2. Select "File" → "Swift Packages" → "Add Package Dependency..." from the menu
3. Enter the following URL in the dialog that appears:
   ```
   https://github.com/CAPHTECH/TemporalKit.git
   ```
4. Choose a version rule (usually "Up to Next Major" is recommended)
5. Click "Next" and then "Finish" to add the package

### Adding to a Package.swift File

If you're using a Package.swift file, add the dependency as follows:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YourPackage",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/CAPHTECH/TemporalKit.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: ["TemporalKit"]
        )
    ]
)
```

## Basic Usage

After installing the package, you can use TemporalKit by adding an import statement:

```swift
import TemporalKit

// Use TemporalKit features
```

## Updating Dependencies

If you want to update dependencies, you have the following options:

### Updating in Xcode
1. Select "File" → "Swift Packages" → "Update to Latest Package Versions" from the menu

### Updating from Command Line
1. Navigate to your project's root directory
2. Run the following command:
   ```bash
   swift package update
   ```

## Troubleshooting

### Package Resolution Issues

If you experience problems with package resolution, try the following steps:

1. Close Xcode
2. Delete the `.build` directory in your project:
   ```bash
   rm -rf .build
   ```
3. Clear the package cache:
   ```bash
   rm -rf ~/Library/Caches/org.swift.swiftpm/
   ```
4. Restart Xcode and resolve the packages again

### Build Errors

If you encounter build errors, check the following:

1. Ensure you're using a compatible Swift and Xcode version
2. Verify that dependencies are correctly configured
3. Clear the cache and build again:
   ```bash
   xcodebuild clean
   ```

## Next Steps

After successfully installing TemporalKit, check out the following documentation:

- [Core Concepts](./CoreConcepts.md) - Learn the fundamental concepts of TemporalKit
- [API Reference](./APIReference.md) - Detailed documentation of available APIs
- [Tutorials](./Tutorials/README.md) - Step-by-step tutorials 
