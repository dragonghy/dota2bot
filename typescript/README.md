## Introduction

This folder is the TypeScript-to-Lua toolchain inherited from upstream OpenHyperAI. It is dev-side only and never ships to the Workshop — the deliverable is the pure Lua under `<root>/bots/`.

Some files under `<root>/bots/` are generated from the ts sources under `<root>/typescript/bots/` (see ARCHITECTURE.md, "TypeScript to Lua (TSTL) Relationship", for exactly which ones). For any change to a TS-generated Lua file, update the ts source and rebuild — otherwise the next build overwrites your Lua edit.

-   More about "Write Lua with TypeScript": https://typescripttolua.github.io/
-   More about Typescript: https://www.typescriptlang.org/

### Developer notes

1. Do not use relative filepath when importing module files with functions like `require` or `dofile` in a ts file. Make sure to use absolute filepath with `bots/` as the root path. TLDR, this is because bot script lua files need to use absolute filepath for any non-in-same-folder path.
1. Always try to modify/update ts files first for any modification, because ts files can replace the lua files and override whatever you might have changed in lua files.
1. When adding/moving files, create the files/folders in typescript in the same file structure as in the root bots folder.

## Usage

1. Install node.
1. Install yarn. `npm install --global yarn`
1. Install dependencies. `yarn install`
1. Run a watcher process to keep re-compiling code for any newly saved changes in TS: `npm run dev`
    - Or, compile to generate lua files only once: `npm run build`

## Release a new version of the bot script

1. Before releasing a new version, run: `npm run release`, this is to auto update script version number, prettify typescript code, convert any possible changes in typescript to lua.
