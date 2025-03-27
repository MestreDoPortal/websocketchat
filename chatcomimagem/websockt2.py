import asyncio
import websockets

clientes = set()

async def chat(websocket, path):
    # Log quando um cliente se conecta
    cliente_id = id(websocket)
    print(f"Cliente conectado: {cliente_id}")
    clientes.add(websocket)
    try:
        async for message in websocket:
            mensagem_formatada = f"{message} from {cliente_id}"
            print(f"Mensagem recebida: {mensagem_formatada}")
            
            # Envia a mensagem para todos os clientes conectados
            for cliente in clientes:
                await cliente.send(mensagem_formatada)
    except websockets.ConnectionClosed:
        print(f"Conexão perdida com o cliente: {cliente_id}")
    finally:
        clientes.remove(websocket)
        # Log quando um cliente se desconecta
        print(f"Cliente desconectado: {cliente_id}")

start_server = websockets.serve(chat, "localhost", 8765)

print("Servidor WebSocket iniciado em ws://localhost:8765")

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
