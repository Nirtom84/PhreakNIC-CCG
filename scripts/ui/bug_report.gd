extends RefCounted
const BASE = "https://github.com/Nirtom84/PhreakNIC-CCG/issues/new?template=bug_report.yml"
static func platform() -> String:
 if OS.has_feature("editor") or not OS.has_feature("template"): return "Running from source (Godot editor)"
 if UIStyle.is_web(): return "Web browser"
 return OS.get_name() if OS.get_name() in ["Windows", "Linux", "Android"] else "Linux"
static func redact(text: String, names: Array, bots: Array, reporter: int) -> String:
 # Replace longest names first; placeholders prevent replacement collisions.
 var indices = range(names.size())
 indices.sort_custom(func(a, b): return str(names[a]).length() > str(names[b]).length())
 for i in indices:
  if not str(names[i]).is_empty(): text = text.replace(str(names[i]), "\u0001%d\u0002" % i)
 var number = 2
 for i in names.size():
  if i != reporter and not bots[i]:
   text = text.replace("\u0001%d\u0002" % i, "Player %d" % number)
   number += 1
  else: text = text.replace("\u0001%d\u0002" % i, str(names[i]))
 return text
static func build(log_text: String = "") -> String:
 var version = str(ProjectSettings.get_setting("application/config/version", ""))
 var device = OS.get_name() + " " + OS.get_version()
 if UIStyle.is_web():
  var agent = JavaScriptBridge.get_interface("navigator").userAgent
  if agent != null: device = str(agent)
 var prefix = BASE + "&version=" + version.uri_encode() + "&platform=" + platform().uri_encode() + "&device=" + device.left(500).uri_encode() + "&log="
 var content = "Version " + version + "\nLog attached with other players’ names removed.\n" + log_text
 while (prefix + content.uri_encode()).length() > 6900: content = content.left(content.length() - 100)
 return prefix + content.uri_encode()
static func open(log_text: String = ""):
 var url = build(log_text)
 if UIStyle.is_web():
  JavaScriptBridge.get_interface("window").open(url, "_blank", "noopener")
 else: OS.shell_open(url)
