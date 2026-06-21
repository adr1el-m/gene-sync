# GeneSync iOS

Native SwiftUI implementation of the GeneSync project paper and Google Stitch mobile design.

## What is included

- Needleman-Wunsch global pairwise alignment
- FASTA cleanup and biological alphabet validation
- DNA, RNA, and protein sequence modes
- Match, mismatch, and gap scoring controls
- Dynamic programming matrix visualization
- Traceback playback
- Percentage identity report
- Monte Carlo sequence-shuffling significance assessment
- Sliding-window hotspot detection
- Local run history

## Run on iPad or iPhone

1. Open `GeneSync.xcodeproj` in Xcode.
2. Install the iOS platform component if Xcode prompts for it.
3. Select the `GeneSync` scheme.
4. Select your connected iPad (A16) or iPhone 15 as the run destination.
5. In Signing & Capabilities, choose your Apple developer team.
6. Press Run.

The app targets iOS 17.0+ and supports iPhone and iPad.

## Local verification commands

```sh
swiftc GeneSync/Models/AlignmentEngine.swift Tests/AlignmentSmoke.swift -o /tmp/AlignmentSmoke && /tmp/AlignmentSmoke
swiftc GeneSync/Models/AlignmentEngine.swift Tests/AlignmentStress.swift -o /tmp/AlignmentStress && /tmp/AlignmentStress
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project GeneSync.xcodeproj -target GeneSync -configuration Debug CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project GeneSync.xcodeproj -target GeneSync -configuration Release CODE_SIGNING_ALLOWED=NO build
```
