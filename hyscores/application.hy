(import [flask [Flask jsonify make_response request]])
(import [werkzeug.security [generate_password_hash check_password_hash]])
(import jwt)

(import [hyscores.authorize [check_token]])
(import [hyscores.mongodb [collection]])


(setv app (Flask __name__)
      secret "very secret"
      users  (collection "users")
      scores (collection "scores"))


#@((app.route "/" :methods ["GET"])
   (defn index []
     (print (.get_json request))
     (print (.get_data request))
     (print (. request headers))
     (print (. request authorization))
     (return (jsonify "Success!"))))


#@((app.route "/register" :methods ["POST"])
    (defn register []
      (setv ok_response (, (jsonify {"result" True}) 200
                           {"Content-Type" "application/json"})
            er_response (, (jsonify {"result" "Invalid request"}) 400
                           {"Content-Type" "application/json"})
            serv_response (, {"result" False} 500
                             {"Content-Type" "application/json"}))

      (if (or (not (. request authorization))
              (not (get (. request authorization) "username"))
              (not (get (. request authorization) "password")))
          (return er_response))
      ;; how to get from dict?
      ;; (if (not (get data "app"))
      ;;     (return er_response))
 
      (setv [login password] (.values (. request authorization))
            data (.get_json request)
            hashed (generate_password_hash password)
            user (users.find_one {"login" login "password" hashed}))

     (if (not user)
          ;; TODO handle DuplicateKeyError
          (setv result (users.insert_one {"login" login
                                          "password" hashed
                                          "app" (get data "app")})
                added? (. result acknowledged))
          (return ok_response))
      (if added?
          (return ok_response)
          (return serv_response))))


#@((app.route "/login" :methods ["POST"])
    (defn login []
      (setv ok_response (, (jsonify {"result" True}) 200
                           {"Content-Type" "application/json"})
            er_response (, (jsonify {"result" "Invalid request"}) 400
                           {"Content-Type" "application/json"}))

      (if (or (not (. request authorization))
              (not (get (. request authorization) "username"))
              (not (get (. request authorization) "password")))
          (return er_response))
      ;; how to get from dict?
      ;; (if (not (get data "app"))
      ;;     (return er_response))

      (setv [login password] (.values (. request authorization))
            data (.get_json request)
            app  (get data "app")
            user (users.find_one {"login" login
                                  "app" app}))
      (if user
          (if (check_password_hash (get user "password") password)
              (do
                (setv token (jwt.encode {"app" app "login" login} secret "HS256"))
                (return (, (jsonify {"result" {"token" token}}) 200)))))

      (return (, (jsonify {"result" "User not found"}) 400))))


#@((app.route "/score" :methods ["GET"])
    check_token
   (defn get_score [user]
     (setv er_response (, (jsonify {"result" "Invalid request"}) 400
                          {"Content-Type" "application/json"})
           data (.get_json request)
           nickname (get data "nickname")
           app (get user "app"))
     
     ;; how to get from dict?
     ;; (if (not (get data "nickname"))
     ;;     (return er_response))

     (setv score (scores.find_one {"app" app "nickname" nickname}))
     (if score
         (return (, (jsonify {"result" {"nickname" (get score "nickname")
                                        "score" (get score "score")}}) 200))
         (return (, (jsonify {"result" "Nickname not found!"}) 400)))))


#@((app.route "/score" :methods ["POST"])
    check_token
   (defn set_score [user]
     (setv er_response (, (jsonify {"result" "Invalid request"}) 400
                          {"Content-Type" "application/json"})
           data (.get_json request)
           nickname (get data "nickname")
           score (get data "score")
           app (get user "app"))
     
     ;; how to get from dict?
     ;; (if (not (get data "nickname"))
     ;;     (return er_response))

     (setv old_score (scores.find_one {"app" app "nickname" nickname}))
     (if old_score
         (if (> score (get old_score "score"))
             (scores.update_one {"app" app "nickname" nickname}
                                {"$set" {"score" score}}))
         (scores.insert_one {"app" app
                             "nickname" nickname
                             "score" score}))
     (return (, (jsonify {"result" True}) 200))))


#@((app.route "/scores" :methods ["GET"])
    check_token
   (defn get_scores [user]
     (setv all_scores (scores.find {"app" (get user "app")})
           data [])
     (for [rec all_scores]
       (.append data {"score" (get rec "score")
                      "nickname" (get rec "nickname")}))
     (return (, (jsonify {"result" data}) 200))))
