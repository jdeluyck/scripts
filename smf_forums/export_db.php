<?php
/* script loosely based on https://www.simplemachines.org/community/index.php?topic=548761.msg3892649#msg3892649 */

/* configuration */
/* Where's your SMF installation? */
$smf_install = "/smf/";

/* where do you want the files? */
$output_dir = "/temp";

require $smf_install . "/Settings.php";

function sanitize_filename($filename) {
	$banned_chars = array(" ", '"', "'", "&", "/", "\\", "?", "#");
	return str_replace($banned_chars, '_', $filename);
}

/* check dir */
if (is_dir($output_dir)) 
	echo "Directory " . $output_dir . " already exists, continuing...<br>". PHP_EOL;
else 
{
	if (mkdir($output_dir))
		echo "Directory " . $output_dir . " successfully created!<br>". PHP_EOL;
	else
		die ("Could not create output directory " . $output_dir . ", please check permissions!<br>");
}

/* Create connection to database */
echo "Connecting to database " . $db_name . "<br>";
$conn = new mysqli($db_server, $db_user, $db_passwd, $db_name);

if ($conn->connect_error)
    die("Connection failed: " . $conn->connect_error);

/* here the fun starts... */
/* Iterate through all categories */
echo "Iterating through categories and boards...<br>". PHP_EOL;
$sql = "SELECT id_cat, name FROM " . $db_prefix . "categories ORDER BY id_cat";
$category_result = $conn->query($sql);

while($category_row = $category_result->fetch_assoc()) 
{
	/* and all boards in this category... */
	$sql = "SELECT id_board, id_cat, id_parent, name FROM ". $db_prefix . "boards WHERE id_cat=" . $category_row["id_cat"] . " ORDER BY id_board";
	$board_result = $conn->query($sql);
	
	while ($board_row = $board_result->fetch_assoc()) 
	{
		$parent = "";
		if ($board_row["id_parent"] != 0)
		{
			/* child board, figure out the parent */
			$sql = "SELECT id_board, name FROM ". $db_prefix . "boards WHERE id_board=" . $board_row["id_parent"];
			$parent_result = $conn->query($sql);
			$parent_row = $parent_result->fetch_assoc();
			$parent = $parent_row["name"];
		}
		
		/* create a filename, and open it */
		$output_filename = $output_dir . "/" . sanitize_filename($category_row["name"] . ($parent == ""?"":"-" . $parent) . "-" . $board_row["name"]) . ".html";
		echo "Writing to " . $output_filename . "<br>" . PHP_EOL;
		$file = fopen($output_filename, "w");
		
		/* output header */
		fwrite($file, "<html><head><title>" . $category_row["name"] . " / " . ($parent == ""?"":"/" . $parent) . $board_row["name"] . "</title></head>" . PHP_EOL);
		fwrite($file, "<body>" . PHP_EOL);

		/* iterate through all topics */
		$sql = "SELECT id_topic FROM " . $db_prefix . "topics WHERE id_board=" . $board_row["id_board"] . " ORDER BY id_topic ASC";
		$topic_id_result = $conn->query($sql);

		while($topic_row = $topic_id_result->fetch_assoc()) 
		{
			/* go through all the messages from this topic */
			$sql = "SELECT * FROM ". $db_prefix . "messages WHERE id_topic=" . $topic_row['id_topic'] . " ORDER BY id_msg ASC";
			$msg_result = $conn->query($sql);
			while ($msg_row = $msg_result->fetch_assoc()) 
			{
				fwrite($file, "<p></p><strong>". $msg_row['subject']."</strong> by ". $msg_row['poster_name']. "<br/>" . PHP_EOL);
				fwrite($file, "Dated: ". date("d/m/Y H:i:s", $msg_row['poster_time'] . "<br /> " . PHP_EOL));
				fwrite($file, $msg_row['body']. "</p>" . PHP_EOL);
			}
			fwrite($file, "<hr />" . PHP_EOL);
		}
		fwrite($file, "</body></html>" . PHP_EOL);
		fclose ($file);
	}
}

echo "All done.</br>";

$conn->close();
?>
