extends "res://online_match.gd"
var replies=[]
var calls=[]
func request(endpoint,body):
	calls.append({"endpoint":endpoint,"body":body.duplicate(true)})
	return replies.pop_front() if not replies.is_empty() else {"ok":false}
