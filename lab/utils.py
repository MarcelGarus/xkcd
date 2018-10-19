import os.path

# The maximum number of comics to assume
max_comics = 10000

# Various file path helpers

def path_of(directory, id, file_type):
  id_with_leading_zeroes = '0' * (4 - len(str(id))) + str(id)
  return '%s/%s.%s' % (directory, id_with_leading_zeroes, file_type)

def path_of_comic(id, file_type = 'png'):
  return path_of('comics', id, file_type)

def path_of_detected_tiles(id):
  return path_of('tiles_detected', id, 'txt')

def path_of_annotated_tiles(id):
  return path_of('tiles_annotated', id, 'txt')

def path_of_merged_tiles(id):
  return path_of('tiles', id, 'txt')

# Checks if a file exists.
def file_exists(path):
  return os.path.isfile(path)

# Copies a file from from_path to to_path.
def copy_file(from_path, to_path):
  with open(from_path) as source:
    with open(to_path, 'wb') as target:
      content = source.read()
      target.write(content.encode('utf-8'))

# Checks if the content of a file starts with the given prefix.
def file_starts_with(file_path, prefix):
  with open(file_path) as f:
    content = f.read()
    return content[:len(prefix)] == prefix
  return False
