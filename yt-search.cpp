#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <iostream>
#include <string>
#include <vector>
#include <regex>
#include <functional>

using json = nlohmann::json;

static size_t write_cb(void *data, size_t size, size_t nmemb, void *userp) {
  auto *str = static_cast<std::string *>(userp);
  auto total = size * nmemb;
  str->append(static_cast<char *>(data), total);
  return total;
}

static std::string url_encode(const std::string &s) {
  CURL *curl = curl_easy_init();
  if (!curl) return s;
  char *enc = curl_easy_escape(curl, s.c_str(), s.size());
  std::string out(enc);
  curl_free(enc);
  curl_easy_cleanup(curl);
  return out;
}

static std::string fetch(const std::string &url) {
  CURL *curl = curl_easy_init();
  if (!curl) return {};
  std::string buf;
  curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
  curl_easy_setopt(curl, CURLOPT_USERAGENT,
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36");
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
  curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 3L);
  curl_easy_setopt(curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
  curl_easy_setopt(curl, CURLOPT_SSL_ENABLE_ALPN, 1L);
  curl_easy_setopt(curl, CURLOPT_TCP_FASTOPEN, 1L);
  curl_easy_setopt(curl, CURLOPT_DNS_CACHE_TIMEOUT, 300L);
  curl_easy_setopt(curl, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
  curl_easy_setopt(curl, CURLOPT_BUFFERSIZE, 256L * 1024L);
  curl_easy_perform(curl);
  curl_easy_cleanup(curl);
  return buf;
}

static std::string extract_yt_initial_data(const std::string &html) {
  auto start = html.find("var ytInitialData = ");
  if (start == std::string::npos) return {};
  start += 20; // length of "var ytInitialData = "
  if (start >= html.size() || html[start] != '{') return {};
  int depth = 0;
  size_t end = start;
  for (; end < html.size(); end++) {
    if (html[end] == '{') depth++;
    else if (html[end] == '}') { depth--; if (depth == 0) { end++; break; } }
  }
  if (depth != 0) return {};
  return html.substr(start, end - start);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    std::cout << "[]\n";
    return 0;
  }

  std::string query = argv[1];
  for (int i = 2; i < argc; i++)
    query += " " + std::string(argv[i]);

  std::string url = "https://www.youtube.com/results?search_query="
                  + url_encode(query);
  std::string html = fetch(url);
  if (html.empty()) {
    std::cout << "[]\n";
    return 1;
  }

  std::string json_str = extract_yt_initial_data(html);
  if (json_str.empty()) {
    std::cout << "[]\n";
    return 1;
  }

  json data;
  try {
    data = json::parse(json_str);
  } catch (...) {
    std::cout << "[]\n";
    return 1;
  }

  json out = json::array();

  std::function<json(const json&, const std::string&)> search =
    [&](const json &node, const std::string &key) -> json {
    if (node.is_object()) {
      auto it = node.find(key);
      if (it != node.end()) return *it;
      for (auto &[k, v] : node.items()) {
        auto r = search(v, key);
        if (!r.is_null()) return r;
      }
    }
    if (node.is_array()) {
      for (auto &v : node)
        if (!v.is_null()) { auto r = search(v, key); if (!r.is_null()) return r; }
    }
    return nullptr;
  };

  auto contents = search(data, "itemSectionRenderer");
  if (contents.is_null() || !contents.is_object()) {
    std::cout << out.dump() << "\n";
    return 0;
  }

  auto items = contents["contents"];
  if (!items.is_array()) {
    std::cout << out.dump() << "\n";
    return 0;
  }

  for (auto &item : items) {
    auto vr = item["videoRenderer"];
    if (vr.is_null()) continue;

    auto video_id = vr["videoId"].get<std::string>();
    auto title = vr["title"]["runs"][0]["text"].get<std::string>();
    auto author = vr["ownerText"]["runs"][0]["text"].get<std::string>();
    std::string duration;
    auto lt = vr["lengthText"];
    if (!lt.is_null())
      duration = lt["simpleText"].get<std::string>();

    out.push_back({
      {"id", video_id},
      {"title", title},
      {"author", author},
      {"duration", duration},
    });
  }

  std::cout << out.dump() << "\n";
  return 0;
}
