package org.achievementlabs.mobile;
import org.json.*;import java.io.*;import java.nio.file.*;import java.security.*;import java.util.*;

// Public, download-only Xbox 360 GPD catalog. Every GPD must match the size and SHA-256 in the index.
final class Gpd360Catalog {
 static final String BASE="https://raw.githubusercontent.com/Achievement-Labs/achievement-labs/gpd-catalog/";
 static final String ISSUE="https://github.com/Achievement-Labs/achievement-labs/issues/new?template=gpd-contribution.yml&title=";
 static final int INDEX_LIMIT=4*1024*1024, GPD_LIMIT=8*1024*1024;
 final File cache;JSONObject titles;
 Gpd360Catalog(File cache){this.cache=cache;}
 static String sha256(byte[] b)throws Exception{StringBuilder s=new StringBuilder();for(byte x:MessageDigest.getInstance("SHA-256").digest(b))s.append(String.format(Locale.ROOT,"%02x",x&255));return s.toString();}
 static boolean titleId(String id){return id!=null&&id.matches("[0-9A-F]{8}")&&!id.equals("FFFE07D1");}
 static JSONObject parse(byte[] bytes)throws Exception{JSONObject root=new JSONObject(new String(bytes,java.nio.charset.StandardCharsets.UTF_8)),titles=root.getJSONObject("titles"),clean=new JSONObject();if(root.optInt("version")!=1)throw new Exception("Unsupported GPD catalog version.");
  for(Iterator<String> keys=titles.keys();keys.hasNext();){String id=keys.next();JSONObject t=titles.getJSONObject(id);int size=t.getInt("bytes");if(!titleId(id)||size<=0||size>GPD_LIMIT||!t.getString("sha256").matches("[0-9a-f]{64}"))throw new Exception("Invalid GPD catalog entry "+id+".");clean.put(id,new JSONObject().put("name",t.optString("name","")).put("achievements",t.optInt("achievements")).put("gamerscore",t.optInt("gamerscore")).put("bytes",size).put("sha256",t.getString("sha256")));}
  return clean;}
 // Falls back to the last verified index when offline.
 synchronized JSONObject index()throws Exception{byte[] bytes;try{bytes=Net.bytes(BASE+"index.json",INDEX_LIMIT);titles=parse(bytes);cache.getParentFile().mkdirs();Profile360Store.atomic(cache,bytes);}catch(Exception error){if(!cache.isFile())throw new Exception("The GPD catalog is unavailable: "+error.getMessage());titles=parse(Files.readAllBytes(cache.toPath()));}return titles;}
 synchronized byte[] fetch(String id)throws Exception{if(titles==null)index();if(!titleId(id)||!titles.has(id))throw new Exception("That title is not in the GPD catalog.");JSONObject t=titles.getJSONObject(id);byte[] data=Net.bytes(BASE+"gpd/"+id+".gpd",GPD_LIMIT);if(data.length!=t.getInt("bytes")||!sha256(data).equals(t.getString("sha256")))throw new Exception("The downloaded GPD did not match the catalog checksum.");return data;}
}
