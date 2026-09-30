from api import app

if __name__ == '__main__':
    # host 0.0.0.0 makes it reachable from phones/emulators on your network.
    # use_reloader=False: the reloader would start the simulation engine twice.
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
