# PepBox Alfred Workflow

Quickly add files to PepBox from Finder using Alfred file actions.

## Installation

1. Double-click `PepBox.alfredworkflow` to install
2. Ensure PepBox 1.0+ is running

## Usage

1. Select files in Finder
2. Activate Alfred (⌘ + Space)
3. Type "Actions" or use your file action hotkey
4. Choose:
   - **Add to PepBox Shelf** → Sends files to the notch shelf
   - **Add to PepBox Basket** → Sends files to the floating basket

## Requirements

- PepBox 1.0+ (with URL scheme support)
- Alfred 4+ with Powerpack

## URL Scheme

The workflow uses PepBox's URL scheme:

```
pepbox://add?target=shelf&path=/path/to/file
pepbox://add?target=basket&path=/path/to/file1&path=/path/to/file2
```

You can use this URL scheme from other apps or scripts too!
