# publish do usuário logado
Meteor.publish 'userData', ->
	unless this.userId
		return this.ready()

	# console.log '[publish] userData'.green

	Meteor.users.find this.userId,
		fields:
			name: 1
			username: 1
			status: 1
			statusDefault: 1
			statusConnection: 1
			avatarOrigin: 1

Meteor.publish 'myRoomActivity', ->
	unless this.userId
		return this.ready()

	# console.log '[publish] myRoomActivity'.green

	# @TODO está deixando lento fazer o relation com usuários

	return Meteor.publishWithRelations
		handle: this
		collection: ChatSubscription
		filter: { 'u._id': this.userId, $or: [ { ts: { $gte: moment().subtract(1, 'days').startOf('day').toDate() } }, { f: true } ] }
		mappings: [
			key: 'rid'
			reverse: false
			collection: ChatRoom
		]

		# return ChatSubscription.find { uid: this.userId, ts: { $gte: moment().subtract(2, 'days').startOf('day').toDate() } }

Meteor.publish 'dashboardRoom', (rid, start) ->
	self = this

	unless this.userId
		return this.ready()

	# console.log '[publish] dashboardRoom ->'.green, 'rid:', rid, 'start:', start

	if typeof rid isnt 'string'
		return this.ready()

	return ChatMessage.find {rid: rid}, {sort: {ts: -1}, limit: 50}

	# cursor = ChatMessage.find {rid: rid}, {sort: {ts: -1}, limit: 50}
	# observer = cursor.observeChanges
	# 	added: (id, record) ->
	# 		self.added 'data.ChatMessage', id, record
	# 	changed: (id, record) ->
	# 		self.changed 'data.ChatMessage', id, record
	# 	removed: (id) ->
	# 		self.removed 'ChatMessage', id
	# @ready()
	# @onStop ->
	# 	observer.stop()

Meteor.publish 'allUsers', ->
	unless this.userId
		return this.ready()

	# console.log '[publish] allUsers'.green

	return Meteor.users.find {username: {$exists: true}, status: {$in: ['online', 'away', 'busy']}}, { 'fields': {
		username: 1
		status: 1
	}}

Meteor.publish 'selectiveUsers', (usernames) ->
	unless @userId
		return @ready()

	# console.log '[publish] selectiveUsers -> '.green, 'userIds:', userIds

	self = @

	query =
		username: $exists: true

	options =
		fields:
			name: 1
			username: 1
			status: 1

	cursor = Meteor.users.find query, options

	observer = cursor.observeChanges
		added: (id, record) ->
			if usernames[record.username]?
				self.added 'users', id, record
		changed: (id, record) ->
			if usernames[record.username]?
				self.changed 'users', id, record
		removed: (id) ->
			if usernames[record.username]?
				self.removed 'users', id

	@ready()
	@onStop ->
		observer.stop()

Meteor.publish 'privateHistoryRooms', ->
	unless this.userId
		return this.ready()

	# console.log '[publish] privateHistoryRooms'.green

	return ChatRoom.find { usernames: Meteor.users.findOne(this.userId).username, t: { $in: ['d', 'c'] } }, { fields: { t: 1, name: 1, msgs: 1, ts: 1, lm: 1, cl: 1 } }

Meteor.publish 'roomSearch', (selector, options, collName) ->
	unless this.userId
		return this.ready()

	# console.log '[publish] roomSearch -> '.green, 'selector:', selector, 'options:', options, 'collName:', collName

	self = @
	subHandleUsers = null

	searchType = null
	if selector.type
		searchType = selector.type
		delete selector.type

	if not searchType? or searchType is 'u'
		subHandleUsers = Meteor.users.find(selector, { limit: 10, fields: { name: 1, username: 1, status: 1 } }).observeChanges
			added: (id, fields) ->
				data = { type: 'u', uid: id, name: fields.name, username: fields.username, status: fields.status }
				self.added("autocompleteRecords", id, data)
			changed: (id, fields) ->
				self.changed("autocompleteRecords", id, fields)
			removed: (id) ->
				self.removed("autocompleteRecords", id)

	subHandleRooms = null

	# @TODO buscar apenas salas de grupo permitidas
	roomSelector = _.extend { t: { $in: ['c'] }, usernames: Meteor.users.findOne(this.userId).username }, selector

	if not searchType? or searchType is 'r'
		subHandleRooms = ChatRoom.find(roomSelector, { limit: 10, fields: { t: 1, name: 1 } }).observeChanges
			added: (id, fields) ->
				roomData = { type: 'r', t: fields.t, rid: id, name: fields.name }

				self.added("autocompleteRecords", id, roomData)
			changed: (id, fields) ->
				self.changed("autocompleteRecords", id, fields)
			removed: (id) ->
				self.removed("autocompleteRecords", id)

	self.ready()

	self.onStop ->
		subHandleUsers?.stop()
		subHandleRooms?.stop()
