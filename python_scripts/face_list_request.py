import requests, json

subkey = '34bae6d8076e4fcab9c31846bf62131f'
list_id = 'list1'

def create_facelist(name):
    headers = {
        # Request headers
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': subkey,
    }

    body = {
        'name': name,
        'userData': 'User-provided data attached to the face list.'
    }

    url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/facelists/' + name

    params = urllib.parse.urlencode({
    })

    r = requests.put(url, data=json.dumps(body), headers=headers)
    print(r.status_code)

def get_facelist(name):
    headers = {
        # Request headers
        'Ocp-Apim-Subscription-Key': subkey,
    }
    url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/facelists/' + name
    r = requests.get(url, headers=headers)
    print(r.status_code)
    print(r.text)

def get_facelists():
    headers = {
        # Request headers
        'Ocp-Apim-Subscription-Key': subkey,
    }
    url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/facelists/' 
    r = requests.get(url, headers=headers)
    print(r.status_code)
    print(r.text)

def delete_facelist(name):
    headers = {
        # Request headers
        'Ocp-Apim-Subscription-Key': subkey,
    }
    url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/facelists/' + name
    r = requests.delete(url, headers=headers)
    print(r.status_code)

def update_facelist(id_, name, userData):
    headers = {
        # Request headers
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': subkey,
    }
    body = {
        'name': name
    }
    if userData is not None:
        body['userData'] = userData
    url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/facelists/' + id_
    r = requests.patch(url, data=json.dumps(body), headers=headers)
    print(r.status_code)

def delete_face(faceListId, persistedFaceId):
    headers = {
        # Request headers
        'Ocp-Apim-Subscription-Key': subkey,
    }
    params = {
        'faceListId' : faceListId,
        'persistedFaceId' : persistedFaceId
    }
    url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/facelists/' + faceListId +'/persistedFaces/' +persistedFaceId
    r = request.delete(url, params=params, headers=headers)
    print(r.status_code)

if __name__ == '__main__':
    #get_facelist('face_list1')
    #get_facelist('face_list2')
    #delete_facelist('face_list2')
    get_facelists()
    #update_facelist('face_list1','list1',None)
    #get_facelists()

####################################