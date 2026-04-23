import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {

static IO.Socket? socket;

static connect(){

socket = IO.io(

"http://10.0.2.2:3000",

IO.OptionBuilder()
.setTransports(['websocket'])
.build()

);

socket!.connect();

}

}