# The lab

The lab is responsible for experimental, cool stuff that makes the app actually
smart. For now, you can read this as "detecting the comic tiles".

The detection of comics happens in this process:
* **Downloading the comics:** All the comics are downloaded by running the
  `fetchcomics.py` file, which simply queries the xkcd api for comic metadata
  and then downloads the comics from the given urls into the `comics` folder
  (not visible on Github, as `comics` folder is `.gitignore`d).
* **Detection of tiles:** For most comics, you can just detect the tiles using
  the `detect.py` script. It floods the background of the image and then
  extracts comic tiles. Have a look at this, it's really interesting!
  It saves the detected tiles in the `tiles_detected` folder in the format
  `<left> <top> <right> <bottom>`, one of these per line in reading order.
  If the generator encounters a comic that's not that easily parseable, it
  writes `needs review` in the first line of the file.
* **Annotating of complex tiles:** For those comics that cannot be handled
  programmatically, `annotate.py` is called. It checks which of the generated
  files starts with a `needs review`. If it finds one, it displays the comic
  for the contributor to annotate using drag-n-drop. The resulting tiles are
  saved in the `tiles_annotated` folder.
* **Merging of datasets:** Finally, the `tiles_generated` and `tiles_annotated`
  datasets are merged into one `tiles` folder, where naturally the
  user-generated tiles get priority over the generated ones.
* **Pushing to Github:** The project gets pushed to this Github repo.
* **Data gets pulled:** The app instances query the tile data from Github.
