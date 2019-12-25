package main

import ("fmt"; "net/http"; "io/ioutil"; "strings")

func main() {
	client := &http.Client{};
	req, _ := http.NewRequest("GET", "https://mail.google.com/a/gmail.com/feed/atom", nil);
	req.SetBasicAuth("louielouie314@gmail.com", "shhcrqtnxonzhhtj");
	resp, _ := client.Do(req);
	defer resp.Body.Close();
	body, _ := ioutil.ReadAll(resp.Body);
	text := string(body);
	open_tag := strings.Index(text, "<fullcount>");
	text = text[open_tag+11:];
	close_tag := strings.Index(text, "</fullcount>");
	count := text[:close_tag];
	if count != "0" {
		fmt.Println("✉", count);
	}
}
