## System architecture diagram (ASCII art or image)


## Data flow diagrams
### `delete_file()`

```text
[User Input: ./recycle_bin.sh delete file.txt]
              |
              v
[Function: delete_file()]
              |
              v
[Validate input and check protected files]
              |
              v
[Extract metadata]
  ├─ basename, realpath
  ├─ stat (size, permissions, owner)
  ├─ file (type)
  └─ date (timestamp)
              |
              v
[Check quota from config]
              |
              v
[Move file to ~/.recycle_bin/files/]
              |
              v
[Append metadata to metadata.db]
              |
              v
[Log operation in recyclebin.log]
              |
              v
[Output: Success or error message to user]
```

### `empty_recyclebin()`

```text
[User Input: ./recycle_bin.sh empty [ID|--force]]
              |
              v
[Function: empty_recyclebin()]
              |
              v
[Check if --force or specific ID provided]
              |
              ├─ If no ID: prompt for confirmation
              |
              v
[Delete matching file(s) from ~/.recycle_bin/files/]
              |
              v
[Update metadata.db]
  ├─ If full purge: reset file with header
  ├─ If specific: remove matching entry
              |
              v
[Log deletion in recyclebin.log]
              |
              v
[Output: Confirmation or error message to user]
```

### `restore_file()`

```text
[User Input: ./recycle_bin.sh restore file_ID]
              |
              v
[Function: restore_file()]
              |
              v
[Search metadata.db for matching ID or name]
              |
              v
[Validate existence of recycled file]
              |
              v
[Check disk space at destination]
              |
              v
[Check if original directory exists]
  ├─ If not: prompt to create
              |
              v
[Check for file conflict at destination]
  ├─ If exists: prompt to overwrite, rename, or cancel
              |
              v
[Move file from recycle bin to original path]
              |
              v
[Restore original permissions with chmod]
              |
              v
[Remove entry from metadata.db]
              |
              v
[Log restoration in recyclebin.log]
              |
              v
[Output: Success or error message to user]
```



## Metadata schema explanation


## Function descriptions

initialize_recyclebin() - Sets up the recycle bin environment by creating necessary directories (files/), the metadata database, configuration file, and log file. Ensures the system is ready for use.

check_disk_space() - Calculates the total size (in bytes) of all files currently stored in the recycle bin by summing the FILE_SIZE column in the metadata. Used to enforce space limits.

delete_file() - Moves one or more files or directories to the recycle bin. Captures metadata (name, path, size, type, permissions, owner), checks for protected files, enforces size limits, and logs the operation.

list_recycled() - Displays the contents of the recycle bin in either compact or detailed format. Supports sorting by name, size, or deletion date via the RECYCLE_BIN_SORT_BY environment variable.

restore_file() - Restores a file from the recycle bin to its original location. Handles name conflicts, missing directories, permission issues, and updates the metadata and log accordingly.

empty_recyclebin() - Permanently deletes all files in the recycle bin or a specific file by ID or name. Supports confirmation prompts and a --force mode for silent deletion.

search_recycled() - Searches the recycle bin metadata for files matching a given pattern (ID or partial name). Displays matching entries with basic metadata for user reference.

auto_cleanup() - Automatically deletes files from the recycle bin that exceed the configured age (AUTO_CLEANUP_DAYS). Updates metadata and logs the cleanup summary including space freed.

show_statistics() - Displays summary statistics about the recycle bin, including total items, total size, usage percentage, file type breakdown, deletion date range, and average file size.


## Design decisions and rationale


## Algorithm explanations


## Flowcharts for complex operations