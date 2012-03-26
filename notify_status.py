#!/usr/bin/python

"""
X7 mq server function
"""
from kombu import BrokerConnection, Exchange, Queue, Consumer, Producer

import sys;

MqDict ={ 'X7_Q':'X7_Q_S2W', 'X7_E':'X7_E_S2W', 'X7_RK':'X7_PK_S2W' }
    
"""
#  read and wait
"""
class MqServer( object ):
    """
    exchange='E_X7_W2S', queue='Q_X7_W2S',routing_key = 'RK_X7_W2S'
    """
    
    def __init__(self, callback, kwargs ):
        self.callback = callback
        if( kwargs ):
            self.kwargs = kwargs
        else:
            self.kwargs = MqDict
        
    def connect(self, hostname="localhost", userid="guest", password="guest", virtual_host="/"): 
        self.conn = BrokerConnection(hostname, userid,password, virtual_host )   
        #define Web2Server exchange
        exchange = Exchange(self.kwargs["X7_E"], type="direct")
        self.queue = Queue(self.kwargs["X7_Q"], exchange, routing_key=self.kwargs["X7_RK"])    
        channel = self.conn.channel()

        consumer = Consumer(channel, self.queue, callbacks=[self.callback])
        consumer.consume()
    
    def run(self, once=False):
        if( once ):
            self.conn.drain_events()
        else:
            while True:
                self.conn.drain_events()
    
    def get(self):
        message = self.queue.get(block=True)
        message.ack()
        return message


class MqClient( object ):
    """
    exchange='E_X7_W2S', queue='Q_X7_W2S',routing_key = 'RK_X7_W2S'
    """
    
    def __init__(self, kwargs ):
        if( kwargs ):
            self.kwargs = kwargs
        else:
            self.kwargs = MqDict
        
    def connect(self, hostname="localhost", userid="guest", password="guest", virtual_host="/"): 
        conn = BrokerConnection(hostname, userid,password, virtual_host )   
        #define Web2Server exchange
        exchange = Exchange(self.kwargs["X7_E"], type="direct")
        #queue = Queue(self.kwargs["X7_Q"], exchange, routing_key=self.kwargs["X7_RK"])    
        channel = conn.channel()

        self.producer = Producer(channel, exchange, routing_key=self.kwargs["X7_RK"])

    def send(self, msg ): 
        self.producer.publish( msg , serializer="json", compression="zlib")
    
    def close(self):
        pass
    
"""
read and no wait
"""
class MqReader( object ):  
    def __init__(self, kwargs ):
        if( kwargs ):
            self.kwargs = kwargs
        else:
            self.kwargs = MqDict
        
    def connect(self, hostname="localhost", userid="guest", password="guest", virtual_host="/"): 
        self.conn = BrokerConnection(hostname, userid,password, virtual_host )   
        #define Web2Server exchange
        exchange = Exchange(self.kwargs["X7_E"], type="direct")
        queue = Queue(self.kwargs["X7_Q"], exchange, routing_key=self.kwargs["X7_RK"])    
        channel = self.conn.channel()
        
        self.bound_queue = queue( channel )   

        #consumer = Consumer(channel, self.queue, callbacks=[self.callback])
        #consumer.consume()
    
    def get(self):
        message = self.bound_queue.get()
        if message is None :
            return None
        
        message.ack()
        return message


def main():
        
	w2sDict = { 'X7_Q':'X7_Q_S2W', 'X7_E':'X7_E_S2W', 'X7_RK':'X7_PK_S2W' }
	client = MqClient( w2sDict )
	client.connect()  
	msg = int(sys.argv[2]) if sys.argv[1] == "prog" else sys.argv[2]
	client.send({"type":sys.argv[1], "mesg":msg})
	print(msg)
	client.close()



if __name__ == "__main__":
	if(len(sys.argv) != 3):
		print "bad parameters"
	else:
		main();

