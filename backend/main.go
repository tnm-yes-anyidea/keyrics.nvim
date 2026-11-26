package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"unicode"
)

type LrcLibResponse struct {
	TrackName    string `json:"trackName"`
	ArtistName   string `json:"artistName"`
	PlainLyrics  string `json:"plainLyrics"`
	SyncedLyrics string `json:"syncedLyrics"`
}

func isMostlyEnglish(text string) bool {
	if text == "" {
		return false
	}
	total, latin := 0, 0
	for _, r := range text {
		if unicode.IsSpace(r) || unicode.IsPunct(r) || unicode.IsSymbol(r) || unicode.IsNumber(r) {
			continue
		}
		total++
		if r <= unicode.MaxASCII || unicode.Is(unicode.Latin, r) {
			latin++
		}
	}
	if total == 0 {
		return false
	}
	return float64(latin)/float64(total) >= 0.90
}

func main() {
	if len(os.Args) < 2 {
		os.Exit(1)
	}

	apiURL := "https://lrclib.net/api/search?q=" + url.QueryEscape(os.Args[1])
	resp, err := http.Get(apiURL)
	if err != nil || resp.StatusCode != 200 {
		fmt.Println("[]")
		os.Exit(1)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var results []LrcLibResponse
	if err := json.Unmarshal(body, &results); err != nil {
		fmt.Println("[]")
		os.Exit(1)
	}

	var filtered []LrcLibResponse
	for _, song := range results {
		if song.PlainLyrics != "" && isMostlyEnglish(song.PlainLyrics) {
			filtered = append(filtered, song)
		}
	}

	if len(filtered) == 0 {
		fmt.Println("[]")
		return
	}

	output, _ := json.Marshal(filtered)
	fmt.Println(string(output))
}
