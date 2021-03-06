import React, { createElement } from 'react';
import styled from 'styled-components';

import NewButton from '../../components/shared/button/NewButton';
import IssueListInfo from '../../components/issue/main/issueMain';

import IssuesStore from '../../stores/IssueStore';
import UserStore from '../../stores/UserStore';
import LabelStore from '../../stores/LabelStore';

import LabelBtn from './button/LabelBtn';
import MilestoneBtn from './button/MilestoneBtn';

const Container = styled.div`
  display: flex;
  flex-direction: column;
  padding: 60px 30px;
  width: 80%;
  max-width: 1400px;
  margin: auto;
`;

const IssueMenu = styled.div`
  display: flex;
  justify-content: space-between;
`;

const MenuDiv = styled.div`
  display: flex;
  flex: ${(props) => props.flex};
`;

const FilterButton = styled.button`
  box-shadow: inset 0px 1px 0px 0px #ffffff;
  background: linear-gradient(to bottom, #f9f9f9 5%, #e9e9e9 100%);
  background-color: #f9f9f9;
  border-radius: 3px;
  border: 1px solid #e8ecef;
  display: inline-block;
  cursor: pointer;
  color: #666666;
  font-family: Arial;
  font-size: 15px;
  font-weight: bold;
  padding: 6px 24px;
  text-decoration: none;
  text-shadow: 0px 1px 0px #ffffff;
`;

const FilterInput = styled.input`
  background: #fafbfc;
  border: 1px solid #e8ecef;
  flex: 1;
  margin-right: 20px;
  padding-left: 20px;
`;

const IssueProvider = ({ contexts, children }) =>
  contexts.reduce(
    (prev, context) =>
      createElement(context, {
        children: prev,
      }),
    children
  );

export default function IssuePage() {
  return (
    <IssueProvider contexts={[IssuesStore, UserStore, LabelStore]}>
      <Container>
        <IssueMenu>
          <MenuDiv flex="1">
            <FilterButton>Filters</FilterButton>
            <FilterInput type="text" placeholder="🔎 Search all issue" />
          </MenuDiv>
          <MenuDiv flex="0">
            <LabelBtn />
            <MilestoneBtn />
          </MenuDiv>
          <MenuDiv flex="0">
            <NewButton link="/issue/post" name="issue" />
          </MenuDiv>
        </IssueMenu>
        <IssueListInfo />
      </Container>
    </IssueProvider>
  );
}
