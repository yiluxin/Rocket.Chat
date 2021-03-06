Template.privateGroupsFlex.helpers
	selectedUsers: ->
		return Template.instance().selectedUsers.get()

	name: ->
		return Template.instance().selectedUserNames[this.valueOf()]

	error: ->
		return Template.instance().error.get()

	autocompleteSettings: ->
		return {
			limit: 10
			# inputDelay: 300
			rules: [
				{
					# @TODO maybe change this 'collection' and/or template
					collection: 'UserAndRoom'
					subscription: 'roomSearch'
					field: 'name'
					template: Template.roomSearch
					noMatchTemplate: Template.roomSearchEmpty
					matchAll: true
					filter:
						type: 'u'
						$and: [
							{ _id: { $ne: Meteor.userId() } }
							{ username: { $nin: Template.instance().selectedUsers.get() } }
						]
					sort: 'name'
				}
			]
		}

Template.privateGroupsFlex.events
	'autocompleteselect #pvt-group-members': (event, instance, doc) ->
		instance.selectedUsers.set instance.selectedUsers.get().concat doc.username

		instance.selectedUserNames[doc.username] = doc.name

		event.currentTarget.value = ''
		event.currentTarget.focus()

	'click .remove-room-member': (e, instance) ->
		self = @
		users = Template.instance().selectedUsers.get()
		users = _.reject Template.instance().selectedUsers.get(), (_id) ->
			return _id is self.valueOf()

		Template.instance().selectedUsers.set(users)

		$('#pvt-group-members').focus()

	'click .cancel-pvt-group': (e, instance) ->
		SideNav.closeFlex()

	'keydown input[type="text"]': (e, instance) ->
		Template.instance().error.set([])

	'click .save-pvt-group': (e, instance) ->
		err = SideNav.validate()
		if not err
			Meteor.call 'createPrivateGroup', instance.find('#pvt-group-name').value, instance.selectedUsers.get(), (err, result) ->
				if err
					return toastr.error err.reason
				SideNav.closeFlex()
				instance.clearForm()
				Router.go 'room', { _id: result.rid }
		else
			Template.instance().error.set(err)

Template.privateGroupsFlex.onCreated ->
	instance = this
	instance.selectedUsers = new ReactiveVar []
	instance.selectedUserNames = {}
	instance.error = new ReactiveVar []

	instance.clearForm = ->
		instance.error.set([])
		instance.selectedUsers.set([])
		instance.find('#pvt-group-name').value = ''
		instance.find('#pvt-group-members').value = ''
