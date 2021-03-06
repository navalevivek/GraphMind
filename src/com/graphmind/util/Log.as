package com.graphmind.util {
	
	import com.graphmind.ApplicationController;
	
	import mx.controls.Alert;
	
	
	public class Log {
		
		public static var LOG_INFO:String = 'INFO';
		public static var LOG_DEBUG:String = 'DEBUG';
		public static var LOG_WARNING:String = 'WARNING';
		public static var LOG_ERROR:String = 'ERROR';

		
		public static function log(text:String, level:String = 'INFO'):void {
			if (!ApplicationController.LOG_MODE) {
				return;
			}
			
			var date:Date = new Date();
			var logMessage:String = level + " -- " + date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds() + "-" + date.getMilliseconds() + " -- " + text;
			
			trace(logMessage);
		}
		

		public static function info(text:String):void {
			log(text, LOG_INFO);
		}
		

		public static function debug(text:String):void {
			log(text, LOG_DEBUG);
		}
		

		public static function warning(text:String):void {
			Alert.show(text, LOG_WARNING);
		}
		

		public static function error(text:String):void {
			log(text, LOG_ERROR);
		}

	}

}
