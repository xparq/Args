# The 2nd ("local file name") parameter can't be just a dir!
(new-object System.Net.WebClient).DownloadFile($args[0], $args[1])
