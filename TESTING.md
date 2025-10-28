# Recycle Bin System - Test Results
**Student Name:** [Your Name]
**Student ID:** [Your ID]
**Date:** [YYYY-MM-DD]
**Script Version:** 1.0
---
## Test Summary
| Category | Total Tests | Passed | Failed | Pass Rate |
|----------|-------------|--------|--------|-----------|
| Basic Functionality | 0 | 0 | 0 | 100% |
| Edge Cases | 0 | 0 | 0 | 100% |
| Error Handling | 0 | 0 | 0 | 100% |
| Performance | 0 | 0 | 0 | 100% |
| **TOTAL** | **0** | **0** | **0** | **q00%** |
---
## Detailed Test Results
### 1. Basic Functionality Tests
#### Test 1.1: Initialize Recycle Bin
- **Status:** ✓ PASS
- **Description:** Verify system initialization creates required directo-
ries
- **Expected:** ~/.recycle_bin/ created with subdirectories
- **Actual:** All directories created successfully
- **Screenshot:** screenshots/init.png

#### Test 1.2: Delete Single File
- **Status:** ✓ PASS
- **Description:** Delete a single file, moving it to recycle_bin
- **Steps:**
1. Created test.txt with content
2. Ran: `./recycle_bin.sh delete test.txt`
3. Verified file moved to recycle bin
- **Expected:** File moved, metadata created
- **Actual:** Success message displayed, file in recycle bin
- **Screenshot:** screenshots/delete_single.png

#### Test 1.3: Delete Multiple Files
- **Status:** ✓ PASS
- **Description:** Delete multiple files, moving them to recycle_bin
- **Steps:**
1. Created test.txt and test2.txt with content
2. Ran: `./recycle_bin.sh delete test.txt test1.txt`
3. Verify files moved to recycle bin
- **Expected:** File moved, metadata created
- **Actual:** Success message displayed, file in recycle bin
- **Screenshot:** screenshots/delete_mult.png

#### Test 1.4: Delete Directory with contents (recursive)
- **Status:** ✓ PASS
- **Description:** Delete a directory with contents
- **Steps:**
1. Created test directory with files inside: testdir/test1.txt and testdir/test2.txt
2. Ran: `./recycle_bin.sh delete test`
3. Verify files moved to recycle bin first and then directory moved aswell.
- **Expected:** Directory moved, files moved, metadata created
- **Actual:** Success message displayed, file in recycle bin
- **Screenshot:** screenshots/delete_rec_directory.png

#### Test 1.5: Delete Empty Directory
- **Status:** ✓ PASS
- **Description:** Delete an empty directory
- **Steps:**
1. Created test directory without any files inside
2. Ran: `./recycle_bin.sh delete test`
3. Verify directory moved to recycle bin
- **Expected:** Directory moved, metadata created
- **Actual:** Success message displayed, file in recycle bin
- **Screenshot:** screenshots/delete_directory.png

#### Test 1.6: Empty entire recycle bin.
- **Status:** ✓ PASS
- **Description:** Deletes with rm -f every file in the recycle_bin.
- **Steps:**
1. With for example the files that created and deleted before in previous tests, we run step 2.
2. Ran: `./recycle_bin.sh empty`
3. Verify files moved to recycle bin are no longer there, and the metadata was erased.
- **Expected:** Empty recycle_bin, metadata removed
- **Actual:** Empty recycle_bin, metadata removed,Success message displayed
- **Screenshot:** screenshots/empty_bin.png

#### Test 1.7: List empty recycle bin
- **Status:** ✓ PASS
- **Description:** List a directory with no contents
- **Steps:**
1. Have the recycle_bin empty.
2. Ran: `./recycle_bin.sh list`
3. Verify that it prints a message stating that the bin is empty.
- **Expected:** Handles the empty bin correctly.
- **Actual:** Success message displayed, empty bin
- **Screenshot:** screenshots/list_empty.png

#### Test 1.8: Empty specific recycle bin file.
- **Status:** ✓ PASS
- **Description:** Deletes with rm -f a specific file in the recycle_bin.
- **Steps:**
1. With a deleted test_empty.txt
2. Ran: `./recycle_bin.sh empty test_empty.txt`
3. Verify the file moved to recycle bin is no longer there, and the metadata was erased.
- **Expected:** Removed File, metadata removed
- **Actual:** Removed File, metadata removed,Success message displayed
- **Screenshot:** screenshots/empty_file.png

#### Test 1.9: List recycle bin
- **Status:** ✓ PASS
- **Description:** List a directory with contents
- **Steps:**
1. Have the recycle_bin with any amount of files.
2. Ran: `./recycle_bin.sh list`
3. Verify that it prints the information of the files in the bin.
- **Expected:** Handles the bin correctly, prints the information.
- **Actual:** Success message displayed, files message
- **Screenshot:** screenshots/list_bin.png

#### Test 1.10: Restore a file to original location
- **Status:** ✓ PASS
- **Description:** Restore a file to original location
- **Steps:**
1. Have a deleted file.
2. Ran: `./recycle_bin.sh list`
3. Verify that the file is now on the original path.
- **Expected:** Handles the file correctly, prints the information.
- **Actual:** Success message displayed, prints the restore destiny, file message
- **Screenshot:** screenshots/restore_file.png

#### Test 1.11: Auto Cleanup
- **Status:** ✓ PASS
- **Description:** Automatically delete files older than AUTO_CLEANUP_DAYS.
- **Steps:**
1. Create a file, and change the deletion date (in metadata.md) to older than AUTO_CLEANUP_DAYS or change this variable to 0, which will delete everything.
2. Ran: `./recycle_bin.sh auto`
3. Verify that the files with the altered dates will no longer be in the bin.
- **Expected:** Handles the file correctly, reads the dates correctly,erases old files.
- **Actual:** Success message displayed, erases old files.
- **Screenshot:** screenshots/auto_cleanup.png

#### Test 1.12: Statistics 
- **Status:** ✓ PASS
- **Description:** Display total number of items in recycle bin, show total storage used with quota percentage, break down by file type (files vs directories), show oldest and newest items, Display average file size
- **Steps:**
1. Ran: `./recycle_bin.sh stats`
3. See multiple statistics of the files inside bin.
- **Expected:** Shows number of files, split by directories and files; percentage of used available storage, show average file size and show the oldest and the newest item.
- **Actual:** Shows total items, total size, percentage usage, number of files and directories, oldest and newest deletion, and average file size.
- **Screenshot:** screenshots/statistics.png



### 2. Edge-cases Tests
#### Test 2.1: Delete non-existant file.
- **Status:** ✓ PASS
- **Description:** Tests to see how it handles the attemp to delete a file that doesn't exist. 
- **Steps:**
2. Ran: `./recycle_bin.sh delete non_existant.txt`
3. Print "Error non-existant: 'non-existant.txt' does not exist"
- **Expected:** Handles the file correctly, prints the error and exits.
- **Actual:** Error message displayed, exits the program safely. 
- **Screenshot:** screenshots/non_existant.png

#### Test 2.2: Delete file without permissions
- **Status:** ✓ PASS
- **Description:** Tests to see how it handles the attemp to delete a file that doesn't have any permissions. 
- **Steps:**
1. Create a file permission0.txt.
2. Ran: `chmod -rwx permission0.txt`
3. Ran: `./recycle_bin.sh delete permission0.txt`
4. Verify that the file was moved to bin.
- **Expected:** Handles the file correctly, moves the file to bin.
- **Actual:** Prints message about deletion, and moves the file. 
- **Screenshot:** screenshots/permission0.png

#### Test 2.3: Restore when original location has same filename
- **Status:** ✓ PASS
- **Description:** Tests to see how it handles the attemp to restore a file when the original location has a a file with the same name. 
- **Steps:**
1. Create a file test.txt.
2. Ran: `./recycle_bin.sh delete test.txt`
3. Create a file test.txt.
4. Ran: `./recycle_bin.sh restore test.txt` (might have to do `./recycle_bin.sh delete ID` if there is more than one test.txt in the recycle_bin).
5. Choose to either overwrite file or restore with a new name.
- **Expected:** Handles the file correctly, no loss of the restored file.
- **Actual:** Prints message of choice and succes, and moves the file to the original path. 
- **Screenshot:** screenshots/SameName.png

#### Test 2.4: Restore with ID that doesn't exist
- **Status:** ✓ PASS
- **Description:** Tests to see how it handles the attemp to restore a file when the ID doesn't exist. 
- **Steps:**
1. Ran: `./recycle_bin.sh restore 12121_121212e`
2. Verify display message stating that there wasn't found any matches.
- **Expected:** Handles the information correctly, no restored file.
- **Actual:** Prints message of error, and recommends using list to check file name's and ID's. 
- **Screenshot:** screenshots/fakeID.png

#### Test 2.4: Restore with ID that doesn't exist
- **Status:** ✓ PASS
- **Description:** Tests to see how it handles the attemp to restore a file when the ID doesn't exist. 
- **Steps:**
1. Ran: `./recycle_bin.sh restore 12121_121212e`
2. Verify display message stating that there wasn't found any matches.
- **Expected:** Handles the information correctly, no restored file.
- **Actual:** Prints message of error, and recommends using list to check file name's and ID's. 
- **Screenshot:** screenshots/fakeID.png

#### Test 2.5: Handle filenames with spaces
- **Status:** ✓ PASS
- **Description:** Tests to see how it handles the a file with spaces. 
- **Steps:**
1. Create file "space test.txt"
2. Ran: `./recycle_bin.sh delete "space test.txt"`
3. Verifiy the recycle_bin and the metadata to check the name of the file.
4. Ran: `./recycle_bin.sh restore "space test.txt"`
5. Verify the original location to check the file still there with the original name.
- **Expected:** Handles the information correctly, deletes and restores file while maintaining the original name.
- **Actual:** Prints message of success,and moves the file maintaining it's spaced name. 
- **Screenshot:** screenshots/spaced.png







---
## Known Issues
### Issue 1: Symbolic Link Handling
- **Description:** Symbolic links are followed instead of being moved
- **Impact:** Medium
- **Workaround:** None currently
- **Plan:** Will implement in future version
### Issue 2: Very Long Filenames
- **Description:** Filenames over 255 characters cause truncation in dis-
play
- **Impact:** Low (display only, functionality works)
- **Workaround:** Use ID for operations
- **Plan:** Implement better truncation algorithm
---
## Performance Observations
- Delete operation: ~0.1s per file
- List operation with 100 items: ~0.3s
- Search operation: ~0.2s
- Restore operation: ~0.15s per file
---
## Conclusion
The recycle bin system successfully implements all required core features
with a 97% test pass rate. One edge case (symbolic links) requires future
enhancement. The system performs well under normal operating conditions
and handles errors gracefully.