# Script that merges the automatically detected tiles with the tiles annotated
# by the user.

from utils import *

def merge_comic(id):
  file_comic = path_of_comic(id)
  file_detected = path_of_detected_tiles(id)
  file_annotated = path_of_annotated_tiles(id)
  file_merged = path_of_merged_tiles(id)
  
  if file_exists(file_annotated):
    copy_file(file_annotated, file_merged)
    print('Comic %d used annotated version' % (id))
  elif file_exists(file_detected) and not file_starts_with(file_detected, 'needs review'):
    copy_file(file_detected, file_merged)
    print('Comic %d used automatically detected version' % (id))
  else:
    print('There is no sufficient tile information about comic %d' % (id))

def merge_all_comics():
  for id in range(max_comics):
    merge_comic(id)

merge_all_comics()
