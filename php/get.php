<?php
// Return the ip for the given key

// Get and validate the key
$key = @$_GET['key'];
if (!preg_match('@^[a-zA-Z0-9_.-]+$@', $key)) {
	header('HTTP/1.1 400 Bad Request');
	exit;
}

// Load the previous saved data
$data = file_exists('.data') ? unserialize(file_get_contents('.data')) : array();

if (isset($data[$key]))
	echo $data[$key];
else
	header('HTTP/1.1 400 Bad Request');
