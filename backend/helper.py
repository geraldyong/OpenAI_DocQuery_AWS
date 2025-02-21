import sys, time
from redis import Redis


def wait_for_redis(host:str="doc_redis", port:int=6379, timeout:int=60):
  """
  Waits for the Redis instance to be ready.

  Args:
    host (str): The hostname for the Redis instance.
    port (int): The port of the Redis instance.
    timeout (int): Maximum time to wait in seconds.

  Returns:
    redis.Client: A connected Redis client.

  Raises:
    TimeoutError: If Redis does not become ready within the timeout period.
  """
  start_time = time.time()
  print(f"INFO: host {host}, port {port}")

  while True:
    try:
      client = Redis.from_url(f"redis://{host}:{port}")

      if client.ping():
        print("Redis is ready!")
        return client
      else:
        print("Redis is not ready yet.")
    except Exception as e:
      print(f"Redis connection error: {e}")

    if time.time() - start_time > timeout:
      print("Redis did not become ready in time.")
      sys.exit(1)
    
    time.sleep(2)