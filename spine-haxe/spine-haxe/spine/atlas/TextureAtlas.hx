package spine.atlas;

import openfl.utils.Assets;
import openfl.errors.ArgumentError;
import openfl.utils.ByteArray;
import openfl.utils.Dictionary;
import openfl.Vector;

class TextureAtlas {
	private var pages = new Vector<TextureAtlasPage>();
	private var regions = new Vector<TextureAtlasRegion>();
	private var textureLoader:TextureLoader;

	public static function fromAssets(path:String) {
		var basePath = "";
		var slashIndex = path.lastIndexOf("/");
		if (slashIndex != -1) {
			basePath = path.substring(0, slashIndex);
		}

		var textureLoader = new AssetsTextureLoader(basePath);
		return new TextureAtlas(Assets.getText(path), textureLoader);
	}

	/** @param object A String or ByteArray. */
	public function new(object:Dynamic, textureLoader:TextureLoader) {
		if (object == null) {
			return;
		}
		if (Std.isOfType(object, String)) {
			load(cast(object, String), textureLoader);
		} else if (Std.isOfType(object, ByteArrayData)) {
			load(cast(object, ByteArray).readUTFBytes(cast(object, ByteArray).length), textureLoader);
		} else {
			throw new ArgumentError("object must be a string or ByteArrayData.");
		}
	}

	private function load(atlasText:String, textureLoader:TextureLoader):Void {
		if (textureLoader == null) {
			throw new ArgumentError("textureLoader cannot be null.");
		}
		this.textureLoader = textureLoader;

		var reader:Reader = new Reader(atlasText);
		var entry:Vector<String> = new Vector<String>(5, true);
		var page:TextureAtlasPage = null;
		var region:TextureAtlasRegion = null;

		var pageFields:Dictionary<String, Void->Void> = new Dictionary<String, Void->Void>();
		pageFields["size"] = function():Void {
			page.width = Std.parseInt(entry[1]);
			page.height = Std.parseInt(entry[2]);
		};
		pageFields["format"] = function():Void {
			page.format = Format.fromName(entry[0]);
		};
		pageFields["filter"] = function():Void {
			page.minFilter = TextureFilter.fromName(entry[1]);
			page.magFilter = TextureFilter.fromName(entry[2]);
		};
		pageFields["repeat"] = function():Void {
			if (entry[1].indexOf('x') != -1)
				page.uWrap = TextureWrap.repeat;
			if (entry[1].indexOf('y') != -1)
				page.vWrap = TextureWrap.repeat;
		};
		pageFields["pma"] = function():Void {
			page.pma = entry[1] == "true";
		};

		var regionFields:Dictionary<String, Void->Void> = new Dictionary<String, Void->Void>();
		regionFields["xy"] = function():Void {
			region.x = Std.parseInt(entry[1]);
			region.y = Std.parseInt(entry[2]);
		};
		regionFields["size"] = function():Void {
			region.width = Std.parseInt(entry[1]);
			region.height = Std.parseInt(entry[2]);
		};
		regionFields["bounds"] = function():Void {
			region.x = Std.parseInt(entry[1]);
			region.y = Std.parseInt(entry[2]);
			region.width = Std.parseInt(entry[3]);
			region.height = Std.parseInt(entry[4]);
		};
		regionFields["offset"] = function():Void {
			region.offsetX = Std.parseInt(entry[1]);
			region.offsetY = Std.parseInt(entry[2]);
		};
		regionFields["orig"] = function():Void {
			region.originalWidth = Std.parseInt(entry[1]);
			region.originalHeight = Std.parseInt(entry[2]);
		};
		regionFields["offsets"] = function():Void {
			region.offsetX = Std.parseInt(entry[1]);
			region.offsetY = Std.parseInt(entry[2]);
			region.originalWidth = Std.parseInt(entry[3]);
			region.originalHeight = Std.parseInt(entry[4]);
		};
		regionFields["rotate"] = function():Void {
			var value:String = entry[1];
			if (value == "true")
				region.degrees = 90;
			else if (value != "false")
				region.degrees = Std.parseInt(value);
		};
		regionFields["index"] = function():Void {
			region.index = Std.parseInt(entry[1]);
		};

		var line:String = reader.readLine();
		// Ignore empty lines before first entry.
		while (line != null && line.length == 0) {
			line = reader.readLine();
		}

		// Header entries.
		while (true) {
			if (line == null || line.length == 0)
				break;
			if (reader.readEntry(entry, line) == 0)
				break; // Silently ignore all header fields.
			line = reader.readLine();
		}

		// Page and region entries.
		var names:Vector<String> = null;
		var values:Vector<Vector<Float>> = null;
		var field:Void->Void;
		while (true) {
			if (line == null)
				break;
			if (line.length == 0) {
				page = null;
				line = reader.readLine();
			} else if (page == null) {
				page = new TextureAtlasPage(line);
				while (true) {
					if (reader.readEntry(entry, line = reader.readLine()) == 0)
						break;
					field = pageFields[entry[0]];
					if (field != null) {
						field();
					}
				}
				textureLoader.loadPage(page, page.name);
				pages.push(page);
			} else {
				region = new TextureAtlasRegion(page, line);
				while (true) {
					var count:Int = reader.readEntry(entry, line = reader.readLine());
					if (count == 0)
						break;
					field = regionFields[entry[0]];
					if (field != null) {
						field();
					} else {
						if (names == null) {
							names = new Vector<String>();
							values = new Vector<Vector<Float>>();
						}
						names.push(entry[0]);
						var entryValues:Vector<Float> = new Vector<Float>(count, true);
						for (i in 0...count) {
							entryValues[i] = Std.parseInt(entry[i + 1]);
						}
						values.push(entryValues);
					}
				}

				if (region.originalWidth == 0 && region.originalHeight == 0) {
					region.originalWidth = region.width;
					region.originalHeight = region.height;
				}

				if (names != null && names.length > 0 && values != null && values.length > 0) {
					region.names = names;
					region.values = values;
					names = null;
					values = null;
				}
				region.u = region.x / page.width;
				region.v = region.y / page.height;
				if (region.degrees == 90) {
					region.u2 = (region.x + region.height) / page.width;
					region.v2 = (region.y + region.width) / page.height;
				} else {
					region.u2 = (region.x + region.width) / page.width;
					region.v2 = (region.y + region.height) / page.height;
				}

				textureLoader.loadRegion(region);
				regions.push(region);
			}
		}
	}

	/** Returns the first region found with the specified name. This method uses string comparison to find the region, so the result
	 * should be cached rather than calling this method multiple times.
	 * @return The region, or null. */
	public function findRegion(name:String):TextureAtlasRegion {
		for (region in regions) {
			if (region.name == name) {
				return region;
			}
		}
		return null;
	}

	public function dispose():Void {
		for (page in pages) {
			textureLoader.unloadPage(page);
		}
	}
}

class Reader {
	private static var trimRegex:EReg = new EReg("^\\s+|\\s+$", "g");

	private var lines:Array<String>;
	private var index:Int = 0;

	public function new(text:String) {
		var regex:EReg = new EReg("[ \t]*(?:\r\n|\r|\n)[ \t]*", "g");
		lines = regex.split(text);
	}

	private function trim(value:String):String {
		return trimRegex.replace(value, "");
	}

	public function readLine():String {
		return index >= lines.length ? null : lines[index++];
	}

	public function readEntry(entry:Vector<String>, line:String):Int {
		if (line == null)
			return 0;
		if (line.length == 0)
			return 0;
		var colon:Int = line.indexOf(':');
		if (colon == -1)
			return 0;
		entry[0] = trim(line.substr(0, colon));
		var i:Int = 1;
		var lastMatch:Int = colon + 1;
		while (true) {
			var comma:Int = line.indexOf(',', lastMatch);
			if (comma == -1) {
				entry[i] = trim(line.substr(lastMatch));
				return i;
			}
			entry[i] = trim(line.substr(lastMatch, comma - lastMatch));
			lastMatch = comma + 1;
			if (i == 4)
				return 4;

			i++;
		}
	}
}