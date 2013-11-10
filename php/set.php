<?php
// Save the given ip for key

// Get and validate the values
$key = @$_GET['key'];
$ip = @$_GET['ip'];
if (!preg_match('@^[a-zA-Z0-9_.-]+$@', $key) || !preg_match('@^(\d{1,3}\.){3}\d{1,3}$@', $ip)) {
	header('HTTP/1.1 400 Bad Request');
	exit;
}

// Load the previous saved data
$data = file_exists('.data') ? unserialize(file_get_contents('.data')) : array();

// Save the data
$data[$key] = $ip;
file_put_contents('.data', serialize($data));
