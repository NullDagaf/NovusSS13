import { useBackend } from '../backend';
import { Section, Stack } from '../components';
import { BooleanLike } from 'common/react';
import { Window } from '../layouts';

type Objective = {
  count: number;
  name: string;
  explanation: string;
  complete: BooleanLike;
  was_uncompleted: BooleanLike;
  reward: number;
};

type Info = {
  antag_name: string;
  objectives: Objective[];
  brothers: string[];
};

export const AntagInfoBrother = (props, context) => {
  const { data } = useBackend<Info>(context);
  const { antag_name } = data;
  return (
    <Window width={620} height={250} theme="syndicate">
      <Window.Content style={{ 'background-image': 'none' }}>
        <Section scrollable fill>
          <Stack vertical>
            <Stack.Item textColor="red" fontSize="20px">
              You are the {antag_name}!
            </Stack.Item>
            <Stack.Item>
              <BrotherPrintout />
            </Stack.Item>
            <Stack.Item>
              <ObjectivePrintout />
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};

const BrotherPrintout = (props, context) => {
  const { data } = useBackend<Info>(context);
  const { brothers } = data;
  return (
    <Stack vertical>
      <Stack.Item bold>Your siblings:</Stack.Item>
      <Stack.Item>
        {(!brothers && 'None!') ||
          brothers.map((sibling) => (
            <Stack.Item key={sibling}>{sibling}</Stack.Item>
          ))}
      </Stack.Item>
    </Stack>
  );
};

const ObjectivePrintout = (props, context) => {
  const { data } = useBackend<Info>(context);
  const { objectives } = data;
  return (
    <Stack vertical>
      <Stack.Item bold>Your objectives:</Stack.Item>
      <Stack.Item>
        {(!objectives && 'None!') ||
          objectives.map((objective) => (
            <Stack.Item key={objective.count}>
              #{objective.count}: {objective.explanation}
            </Stack.Item>
          ))}
      </Stack.Item>
    </Stack>
  );
};
