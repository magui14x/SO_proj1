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

**1. File Structure**
The project required multiple tasks that compelled the creation of multiple files for configuration, and data storage.

metadata.db - Created to hold data of each deleted file. Allowed manipulation and the search of files inside the bin.

config - Holds certain values that can be changed to set the code to the users comfort.

recyclebin.log - Holds the information of each operation realized.


**2. UI**

The User interface in this project is run in the terminal. We tried to adapt everything for a comprehensive view of the information displayed. 
We used a table-like view for the list, a simple but detailed description of the performed action before and after it is complete to allow the user to understand what happens through each command. The creation of the help command also intends to allow a better understanding of each command.

**3.Error Handling**

The majority of error handling is solved by an "if check" that verifies a specific situation. It allows for simple exits in case it finds a situation that can't handle. Also there are some other cases, like the "flock" that cancels operations when there are multiple concurrent.

**4. Size Limit Handling**

The size limit placed on the recycle_bin is checked in multiple functions.

Delete - Doesn't let the user delete a file if this action will surpass the size limit inside the bin.

List and Stats - Check for the current use of the space and, if it is close to the limit it will advise the user to take action.

**5. Returns**
When the code succeeds it returns 0, else it return 1.

## Algorithm explanations

**Initialize recycle_bin** 

With just a few changes from the template, we added the creation of the config file that stores the values for MAX_SIZE_MB and AUTO_CLEANUP_DAYS, and the creation of recyclebin.log, which allows us to store information about each operation. On the first initialization of the bin, the operation is recorded in the log.

**Generate unique ID**

Attaching the timestamp of the function call with 6 random characters it generates an unique ID.

**Check disk space**

This function was created to allow the calculation of the current occupied space, which is then compared with the allowed space in MAX_SIZE_MB. We believe it simplifies the process of obtaining that value, which is later used to calculate usage percentage in the list and statistics functions.


**Delete File**
In the delete file function, we created several validations to ensure that the file is handled according to its characteristics.

First, in the block with if [ "$#" -eq 0 ]; then, we check for the presence of arguments. This prevents the code from running if none are provided.

With for file_path in "$@"; do, we start a for loop that goes through each argument. This seemed like the best choice since it can handle any number of arguments, whether one or many.

We check that none of the arguments are files that are part of the project (for example: if one of the arguments is $RECYCLE_BIN_DIR, which would be the bin directory, that argument is ignored, and a warning message is shown for attempting to delete an important file).

if [ ! -e "$file_path" ]; then ensures that the file exists.

if [ -L "$file_path" ]; then allows us to detect a symbolic link file, but we ended up not implementing its handling correctly.

if [[ -d "$file_path" && ! -L "$file_path" ]]; then ensures that we're working with a non-symbolic directory, so we can recursively delete its contents if there are any.

Then we have a block that uses stat, file, and generate_unique_ to create metadata for each argument being processed. It also creates a new name for the file by joining the old name with the ID.

Immediately after, we calculate the current usage of bin space, which allows us to prevent deletion of a file if it would exceed MAX_SIZE_MB.

exec 200>>"$METADATA_FILE" flock -n 200 || {...} is a measure used to prevent two processes from running at the same time. It allows the first process that reaches this point to block the second. This is an extreme measure, but it ensures that files aren’t duplicated if two processes with the same argument are run simultaneously.

Then it tries to move the file to the bin. This can fail if the process doesn’t have permission to move the file.

**List recycled**
First off, "if [[ "$1" == "--detailed" || "$1" == "-d" ]]; then" checks for the --detailed flag. 

Then, checks to see if the metadata is empty. Counts the number of files, and  if "[ "$total_items" -eq 0 ]" it prints a message stating that the bin is empty.

Calculates the total size of the files in the bin.

After that, depending on if it had the detailed flag or not, it adjusts the display of information that the user will see.

Check the sort_by, (which can be changed by doing an export RECYCLE_BIN_SORT_BY=name/size/date) to decide in what order to sort the data.

The main difference between detailed and compact view is the information displayed.

Detailed view creates an individual indexed table for each file with all the information in the metadata: id, name, path, deletion_date, size, type, permissions, owner. Also shows the name the file was stored with, converts the size from bytes to kB or MB (if it needs to) and shows a preview of the first line of the file.

Compact view shows simply the ID, name, original path, size and deletion date.

After that, displays a summary of the information of all the files. Prints all the files, total size, the sort key, and percent usage.

**Restore file**

Checks if it has a search term, if the metadata file exists, and if the metadata is empty, returning 1 if it doesn't verify all those checks.

From the search term, the code gets the id and the name of the first matching file. If it doesn't match anything with the search term, returns 1 and recommends using list.

If it finds a metadata entry, parses it's fields "(IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$metadata_entry")" and stores it's values and prints them.

It then looks for the physical file, using the ID in the new_name, and matches the type of file it is. It looks for the first matching instance of the search term. If it doesn't find the physical file, prints the error and returns 1.

Checks for disk space in the original path, and stops the operation only if there isn't enough space.

Then it has to check if the original directory still exists. If it doesn't, asks if the user wants to create that directory again. Here there are 3 possible paths:

1- There is an error creating the directory, so it prints error message and returns.
2- It creates the directory successfully, prints message and continues to move the file
3-The file creation is canceled, prints the cancelling message and returns.

If the directory already existed, but was read-only, it asks the user to see if he wishes to give it the necessary permissions to perform the restoration. If it fails to give the permissions, prints error message and returns. If the operation is cancelled prints the cancelling message and returns.

After the directory check, it checks for the existence of a file with the same filename inside that directory. If there is, it makes a read,case that depends on 1 of 3 choices:
1) Overwrite existing file
2) Restore with modified name (append timestamp)
3) Cancel operation
*) Invalid choice

1- If it is a directory and there is an error on removing the file prints error and returns. If it is a file and there is an error removing it prints an error and returns.

2- It appends the name a timestamp, so it is unique, while also saving the file extension to place it only in the end of the new name.

3- Cancels restoration, prints cancelled message, returns.

*- Asks the user for a valid input.

If there isn't a file in the original path with the same filename the function will proceed normally.

Checks if the recycled_file can be moved to the destination, if not prints error and returns.

Checks if the permissions are valid, to try to restore them. If it fails Prints warning saying that the permissions could not be restored, but continues the procedure as normal.

To remove the metadata entry, it moves everything in the metadata, except the matching line ,to a temporary file. Then, overwrites the metadata with the information of this temporary file, destroying it in the  process. Which gives us the filtered out result. If it can't update the metadata, it issues a warning, and destroys the temp file (but this situation should be very rare). If it can't find the metadata entry issues a warning and destroys the temporary file.

Also creates a Log entry stating the success of operation or if it failed before, it is also logged then.

**Empty bin**

Checks if the argument is the flag --force. If it is, changes the target to "" and makes the variable "force" true (é uma ferramenta surpresa que nos ajudará mais tarde).

If there was no argument, it will ask for confirmation before trying to delete every file. If the variable "force" has the value true, it will not ask for confirmation before deleting all the files inside the recycle bin.

It resets the metadata and prints the success message, while also logging the procedure.

If there was an argument in the function call that wasn't the flag, it will look for the lines in the metadata that match the search term, while also storing the matches. And printing the matches with an incremental index attached.

If the number of matches is zero, it will print the error of no matches and return.

It will wait for the user to select the index of the file that he intends to delete. If the Index isn't one of the choices the operation will be canceled.

If the input matches one of the indexes, it will start working with it.

It will find the entry in the metadata, delete it through the same method that was used on the restore function, but only if it is able to remove the file itself, with rm -rf. If it wasn't able to delete the file it prints an error message and returns. If the physical file didn't exist at all, It will print the warning not found and it will return.


**Search Bin**

If it doesn't receive a pattern, prints the error no pattern provided and returns.

If it doesn't find the metadata file issues a warning and returns.

If it checks the normal boxes, it prints a header, and then parses de files. It first checks what type of pattern was given. It checks if starts with "*." so it can look for the extension that follows after. If it finds a match, it prints it's information, indexes it, counts the matches and changes the variable to found. 

Similar thing in case it is looking for the name or path. If it finds a match, it prints it's information, indexes it, counts the matches and changes the variable to found. 

If found = 0 issue warning and return.

**Auto Cleanup**

Check for the existence of the config file.. If it doesn't exist, it issues a warning and returns.

Checks for the variable auto-cleanup days in the config file to use it in the calculations.
If that variable isn't valid, it prints an error and returns.

The function gets the present date. Parses the metadata, skips header and entries without a valid deletion date (while issuing a warning) and selects the ones where the difference between the current date and the deletion date is bigger than the AUTO_CLEANUP_DAYS.

If the current entry is an old file, it will count it for the deleted_count, and will also make a sum of the freed space after using the function.

If the entry is a file, deletes it with rm -f. If it's a directory, deletes it with rmdir. 

If there are deleted files it also deletes the metadata entry of each one, using the ID to find them.

In the end writes a summary containing the cleanup days, the deleted files count and the total space freed.

**Statistics**


## Flowcharts for complex operations