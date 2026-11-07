/// Contratos de saída; o repositório também valida os dados recebidos.
abstract final class GeminiSchemas {
  static const recipe = <String, Object?>{
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'ingredients': {
        'type': 'array',
        'items': {'type': 'string'},
        'minItems': 1,
      },
      'steps': {
        'type': 'array',
        'items': {'type': 'string'},
        'minItems': 1,
      },
      'preparationMinutes': {'type': 'integer', 'minimum': 1},
      'servings': {'type': 'integer', 'minimum': 1},
    },
    'required': [
      'title',
      'description',
      'ingredients',
      'steps',
      'preparationMinutes',
      'servings',
    ],
    'additionalProperties': false,
  };

  static const foods = <String, Object?>{
    'type': 'object',
    'properties': {
      'foods': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['foods'],
    'additionalProperties': false,
  };
}
