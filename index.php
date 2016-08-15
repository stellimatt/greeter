<?php

  function get_random_greeting() {
    $servername = "localhost";
    $dbname = "greeter";
    $username = "root";
    $password = "password";

    try {
      $conn = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
      // set the PDO error mode to exception
      $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
      $stmt = $conn->prepare('select greeting from greetings order by rand() limit 1');
      $stmt->execute();

      $result = $stmt->fetch();
      echo $result[0];
    } catch(PDOException $e) {
      //echo "Connection failed: " . $e->getMessage();
    }
  }

  echo "<h1>" . get_random_greeting() . "</h1>";

?>
