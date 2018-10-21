# This script downloads all the comics from the xkcd api.
# ~ Marcel

import json
import subprocess
import urllib
import urllib.request
from utils import *

# Returns the id of the latest comic.
def get_latest_id():
  print('Getting id of the latest comic')
  content = urllib.request.urlopen('http://xkcd.com/info.0.json').read()
  parsed_json = json.loads(content)
  id = parsed_json['num']
  print('Latest id is %d' % (id))
  return parsed_json['num']

# Downloads the comic with the given id if it's not already downloaded.
def download_comic(id: int):
  comic_path = path_of_comic(id)

  if file_exists(comic_path) or file_exists(path_of_comic(id, file_type='gif')):
    print('Comic %d already downloaded.' % (id))
    return

  # get url of the comic
  print('Comic %d: Fetching metadata' % (id))
  try:
    metadata_url = 'http://xkcd.com/%d/info.0.json' % (id)
    content = urllib.request.urlopen(metadata_url).read()
  except:
    print('Comic %d: Metadata not available' % (id))
    return # not available
  metadata = json.loads(content)
  img_url = metadata['img']

  # download the image
  print('Comic %d: Downloading from %s' % (id, img_url))
  file_type = img_url[img_url.rfind('.')+1:]
  comic_path = path_of_comic(id, file_type = file_type)
  f = open(comic_path, 'wb')
  f.write(urllib.request.urlopen(img_url).read())
  f.close()
  print('Comic %d: Download finished. Saved as %s' % (id, comic_path))

  # convert image to png except gifs (because they expand to a bunch of images)
  elif file_type != 'png' and file_type != 'gif':
    print('Comic %d: Converting to png' % (id))
    old_comic_path = comic_path
    comic_path = path_of_comic(id)
    subprocess.Popen([ 'convert', old_comic_path, comic_path ]).wait()
    subprocess.Popen([ 'rm', comic_path ]).wait()
    print('Comic %d: Done converting. Saved as %s' % (id, comic_path))


# Downloads all comics.
def download_all_comics():
  latest_id = get_latest_id()
  print('Downloading all comics')

  for id in range(1, latest_id):
    download_comic(id)


download_all_comics()
