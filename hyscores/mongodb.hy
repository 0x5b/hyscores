(import pymongo
        pymongo [MongoClient])


(setv CONFIG {"address" "127.0.0.1"
              "port"     27017
              "db_name"  "hyscores"})


(defclass Database []
  "Database wrapper."

  (defn __init__ [self]
    (setv self.address (get CONFIG "address")
          self.port    (get CONFIG "port")
          self.name    (get CONFIG "db_name")
          self._db     (get (MongoClient self.address self.port)
                            self.name)))

  (defn __getattr__ [self name]
    (setv value (getattr self._db name))
    (if (isinstance value pymongo.collection.Collection)
        (return (Collection value))
        (return value)))

  (defn __getitem__ [self name]
    (return (Collection (get self._db name)))))


(defclass Collection []
  "Collection wrapper."

  (defclass CallProxy []
    (defn __init__ [self func]
      (setv self._func func))
    (defn __call__ [self #*args #**kwargs]
      (return (self._func #*args #**kwargs))))

  (defn __init__ [self collection]
    (setv self._collection collection))

  (defn __getattr__ [self name]
    (setv value (getattr self._collection name))
    (if (callable value)
        (return (self.CallProxy value))
        (return value)))

  (defn __getitem__ [self name]
    (return (get self._collection name))))


(defn collection [name]
  (return (get (Database) name)))
