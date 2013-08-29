package net.psykosoft.io
{

	import flash.utils.ByteArray;

	public class IOExtension
	{
		public function IOExtension() {
			super();
		}

		// -----------------------
		// Native interface.
		// -----------------------

		public function write( bytes:ByteArray, fileName:String ):void {
		}

		public function read( bytes:ByteArray, fileName:String ):void {
		}

		public function writeWithCompression( bytes:ByteArray, fileName:String ):void {
		}

		public function readWithDeCompression( bytes:ByteArray, fileName:String ):void {
		}

		public function mergeRgbaPerByte( bytes:ByteArray ):void {
		}

		public function mergeRgbaPerInt( bytes:ByteArray ):void {
		}
	}
}