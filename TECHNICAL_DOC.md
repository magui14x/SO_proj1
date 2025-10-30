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


## Design decisions and rationale


## Algorithm explanations


## Flowcharts for complex operations