import json
import os.path
import subprocess
import urllib
import urllib.request

# Returns the id of the latest comic.
def get_latest_id():
  print('Getting id of the latest comic')
  content = urllib.request.urlopen('http://xkcd.com/info.0.json').read()
  parsed_json = json.loads(content)
  id = parsed_json['num']
  print('Latest id is %d' % (id))
  return parsed_json['num']


def get_file_name(id, file_type):
  id_with_leading_zeroes = '0' * (4 - len(str(id))) + str(id)
  return 'comics/%s%s' % (id_with_leading_zeroes, file_type)

# Downloads the comic with the given id to comics/ if its's not already there.
def download_comic_by_id(id):
  if os.path.isfile(get_file_name(id, '.png')):
    print('Comic %d already downloaded.' % (id))
    return

  # get url of the comic
  print('Fetching metadata for comic #%d' % (id))
  try:
    content = urllib.request.urlopen('http://xkcd.com/%d/info.0.json' % (id)).read()
  except:
    print('Metadata not available')
    return # not available
  parsed_json = json.loads(content)
  url = parsed_json['img']

  # download the image
  print('Downloading comic from %s' % (url))
  file_type = url[url.rfind('.'):]
  file_name = get_file_name(id, file_type)
  f = open(file_name, 'wb')
  f.write(urllib.request.urlopen(url).read())
  f.close()
  print('Download finished. Saved as %s' % (file_name))

  # convert image to png
  if file_type is not '.png':
    print('Converting to png.')
    new_file_name = get_file_name(id, '.png')
    subprocess.Popen([ 'convert', file_name, new_file_name ]).wait()
    subprocess.Popen([ 'rm', file_name ]).wait()
    print('Done converting. Saved as %s' % (new_file_name))


# Downloads all comics.
def download_all_comics():
  latest_id = get_latest_id()
  print('Downloading all comics')

  for id in range(1, latest_id):
    download_comic_by_id(id)


download_all_comics()
