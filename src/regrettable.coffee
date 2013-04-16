_ = if require? then require("underscore") else window._
Backbone = if require? then require("backbone") else window.Backbone

class Action
  constructor: ->
  undo: ->
  redo: ->

class CollectionAddAction extends Action
  constructor: (@collection, @model, @caid) ->
  undo: -> @model.destroy()
  redo: -> @model = @model.clone(); @collection.add(@model)

class CollectionRemoveAction extends Action
  constructor: (@collection, @model, @caid) ->
  undo: -> @model = @model.clone(); @collection.add(@model)
  redo: -> @model.destroy()

class ModelPropertyUpdateAction extends Action
  constructor: (@model, @prop, @newVal, @oldVal, @caid) ->
  undo: -> @model.set(@prop, @oldVal)
  redo: -> @model.set(@prop, @newVal)

class ModelUpdateAction extends Action
  constructor: (@model, @caid) ->
    @actions = []
    for attr, newVal of @model.changedAttributes()
      @actions.push(new ModelPropertyUpdateAction(@model, attr, newVal, @model.previous(attr), @caid))

  undo: -> _.invoke @actions, 'undo'
  redo: -> _.invoke @actions, 'redo'

Backbone.Regrettable = (->

  undoStack = []
  redoStack = []
  tracking = true
  composite = false
  redoing_caid = undefined
  undoing_caid = undefined
  tracking: (t) -> tracking = t
  undoStack: -> undoStack
  redoStack: -> redoStack
  undo: (caid) ->
    return if undoStack.length == 0 or (caid? and caid != _.last(undoStack).caid)
    try
      tracking = false
      action = undoStack.pop()
      action.undo()
      redoStack.push(action)
      if action.caid
        @undo(action.caid)
    finally
      tracking = true
  redo: (caid) ->
    return if redoStack.length == 0 or (caid? and caid != _.last(redoStack).caid)
    try
      tracking = false
      action = redoStack.pop()
      action.redo()
      undoStack.push(action)
      if action.caid
        @redo(action.caid)
    finally
      tracking = true
  hasUndo: ->
    return undoStack.length > 0
  hasRedo: ->
    return redoStack.length > 0
  reset: ->
    undoStack = []
    redoStack = []
  startComposite: -> composite = _.uniqueId("ca")
  stopComposite: -> composite = undefined
  bind: (o, opts = {}) ->
    ignore = opts.ignore || (-> false)
    if o instanceof Backbone.Model
      o.on "change", (model, opts) ->
        if tracking && not ignore(model, opts)
          redoStack = []
          undoStack.push(new ModelUpdateAction(model, composite if composite))
    else if o instanceof Backbone.Collection
      o.on "add", (prod, coll, opts) ->
        if tracking && not ignore(prod, coll, opts)
          redoStack = []
          undoStack.push(new CollectionAddAction(o, prod, composite if composite))
      o.on "remove", (prod, coll, opts) ->
        if tracking && not ignore(prod, coll, opts)
          redoStack = []
          undoStack.push(new CollectionRemoveAction(o, prod, composite if composite))
)()


if module?.exports?

  _.extend Backbone.Regrettable,
    CollectionAddAction: CollectionAddAction
    CollectionRemoveAction: CollectionRemoveAction
    ModelUpdateAction: ModelUpdateAction

  module.exports = Backbone.Regrettable




