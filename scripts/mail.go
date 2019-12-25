package main

import ("fmt"; "net/http"; "io/ioutil")

func main() {
	resp, _ := http.Get("https://wttr.in/Moscow?format=3");
	defer resp.Body.Close()
	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Println(string(body))
}
