export const labelReducer = (labels, { type, payload }) => {
  switch (type) {
    case 'SET_INIT_DATA':
      return payload;

    case 'DELETE_LABEL':
      return labels.filter((label) => label.id !== payload);

    default:
      break;
  }
};

export const newReducer = (isClickNew, { type }) => {
  switch (type) {
    case 'NEW_LABEL_TAB_OPEN':
      return true;
    default:
      break;
  }
};
