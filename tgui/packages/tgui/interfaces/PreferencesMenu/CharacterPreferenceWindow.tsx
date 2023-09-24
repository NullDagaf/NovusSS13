import { exhaustiveCheck } from 'common/exhaustive';
import { useBackend, useLocalState } from '../../backend';
import { Stack, Button, Box, Dropdown } from '../../components';
import { Window } from '../../layouts';
import { GhostRole, PreferencesMenuData, ServerData } from './data';
import { PageButton } from './PageButton';
import { AntagsPage } from './AntagsPage';
import { JobsPage } from './JobsPage';
import { MainPage } from './MainPage';
import { MarkingsPage } from './MarkingsPage';
import { BackgroundPage } from './BackgroundPage';
import { SpeciesPage } from './SpeciesPage';
import { QuirksPage } from './QuirksPage';
import { ServerPreferencesFetcher } from './ServerPreferencesFetcher';

enum Page {
  Antags,
  Main,
  Markings,
  Background,
  Jobs,
  Species,
  Quirks,
}

const CharSlots = (props: {
  onClick: (action: string, payload?: object) => void;
  profiles: string[];
  slotKey: string;
  maxSlots: number;
  activeSlot: number;
}) => {
  const profileoptions: string[] = [];
  for (let profile of props.profiles) {
    profileoptions.push(profile);
  }
  return (
    <>
      <Dropdown
        minWidth={10}
        selected={profileoptions[props.activeSlot - 1] || 'None'}
        options={profileoptions}
        onSelected={(option) => {
          props.onClick('change_slot', {
            slot_key: props.slotKey,
            slot_id: profileoptions.indexOf(option) + 1,
          });
        }}
      />
      {Number(profileoptions.length) < props.maxSlots && (
        <Stack.Item>
          <Button
            icon="plus"
            onClick={() => {
              props.onClick('new_slot', {
                slot_key: props.slotKey,
              });
            }}
            fluid
          />
        </Stack.Item>
      )}
    </>
  );
};

export const CharacterPreferenceWindow = (props, context) => {
  const { act, data } = useBackend<PreferencesMenuData>(context);

  const [currentPage, setCurrentPage] = useLocalState(
    context,
    'currentPage',
    Page.Main
  );

  let pageContents;

  switch (currentPage) {
    case Page.Antags:
      pageContents = <AntagsPage />;
      break;
    case Page.Jobs:
      pageContents = <JobsPage />;
      break;
    case Page.Main:
      pageContents = (
        <MainPage openSpecies={() => setCurrentPage(Page.Species)} />
      );

      break;
    case Page.Markings:
      pageContents = (
        <MarkingsPage openSpecies={() => setCurrentPage(Page.Species)} />
      );
      break;
    case Page.Background:
      pageContents = (
        <BackgroundPage openSpecies={() => setCurrentPage(Page.Species)} />
      );
      break;
    case Page.Species:
      pageContents = (
        <SpeciesPage closeSpecies={() => setCurrentPage(Page.Main)} />
      );
      break;

    case Page.Quirks:
      pageContents = <QuirksPage />;
      break;
    default:
      exhaustiveCheck(currentPage);
  }

  return (
    <Window title="Character Preferences" width={920} height={770}>
      <Window.Content scrollable>
        <Stack vertical fill>
          {data.is_guest ? (
            <Stack.Item align="center">
              Create an account to save your character!
            </Stack.Item>
          ) : (
            <Stack.Item>
              <Stack justify="center" fill>
                <Stack.Item>
                  <Stack vertical fill fluid>
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <ServerPreferencesFetcher
                            render={(render_data: ServerData | null) => {
                              if (!render_data) {
                                return <Box>Loading categories..</Box>;
                              }

                              const ghost_role_data: Record<string, GhostRole> =
                                render_data.ghost_role_data;

                              const categoryoptions: string[] = ['Main'];
                              const categorykeys: string[] = ['main'];
                              let active_slot_name = 'Main';
                              Object.keys(ghost_role_data).map((key, index) => {
                                categoryoptions.push(
                                  ghost_role_data[key].slot_name
                                );
                                categorykeys.push(
                                  ghost_role_data[key].savefile_key
                                );
                                if (
                                  ghost_role_data[key].savefile_key ===
                                  data.active_slot_key
                                ) {
                                  active_slot_name =
                                    ghost_role_data[key].slot_name;
                                }
                              });

                              return (
                                <Dropdown
                                  width={10}
                                  justify="center"
                                  selected={active_slot_name || 'Main'}
                                  options={categoryoptions}
                                  onSelected={(category_name: string) => {
                                    if (
                                      currentPage === Page.Species ||
                                      currentPage === Page.Antags ||
                                      currentPage === Page.Jobs
                                    ) {
                                      setCurrentPage(Page.Main);
                                    }
                                    act('change_category', {
                                      slot_key:
                                        categorykeys[
                                          categoryoptions.indexOf(category_name)
                                        ] || 'Main',
                                    });
                                  }}
                                />
                              );
                            }}
                          />
                        </Stack.Item>
                        <Stack.Item>
                          <Stack justify="center">
                            <CharSlots
                              profiles={
                                data.character_profiles[data.active_slot_key]
                              }
                              activeSlot={data.active_slot_ids['main']}
                              slotKey="main"
                              maxSlots={data.max_slots_main}
                              onClick={(action, object) => {
                                act(action, object);
                              }}
                            />
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                    {!data.content_unlocked && (
                      <Stack.Item align="center">
                        Buy BYOND premium for more slots!
                      </Stack.Item>
                    )}
                  </Stack>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          )}
          <Stack.Divider />

          <Stack.Item>
            <Stack fill>
              <Stack.Item grow>
                <PageButton
                  currentPage={currentPage}
                  page={Page.Main}
                  setPage={setCurrentPage}
                  otherActivePages={[Page.Species]}>
                  Character
                </PageButton>
              </Stack.Item>

              <Stack.Item grow>
                <PageButton
                  currentPage={currentPage}
                  page={Page.Markings}
                  setPage={setCurrentPage}>
                  Markings
                </PageButton>
              </Stack.Item>

              <Stack.Item grow>
                <PageButton
                  currentPage={currentPage}
                  page={Page.Background}
                  setPage={setCurrentPage}>
                  Background
                </PageButton>
              </Stack.Item>

              {data.active_slot_key == 'main' && (
                <>
                  <Stack.Item grow>
                    <PageButton
                      currentPage={currentPage}
                      page={Page.Jobs}
                      setPage={setCurrentPage}>
                      {/*
                    Fun fact: This isn't "Jobs" so that it intentionally
                    catches your eyes, because it's really important!
                  */}
                      Occupations
                    </PageButton>
                  </Stack.Item>

                  <Stack.Item grow>
                    <PageButton
                      currentPage={currentPage}
                      page={Page.Antags}
                      setPage={setCurrentPage}>
                      Antagonists
                    </PageButton>
                  </Stack.Item>
                </>
              )}

              <Stack.Item grow>
                <PageButton
                  currentPage={currentPage}
                  page={Page.Quirks}
                  setPage={setCurrentPage}>
                  Quirks
                </PageButton>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Divider />

          <Stack.Item>{pageContents}</Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
